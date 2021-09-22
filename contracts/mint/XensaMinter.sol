pragma solidity ^0.5.0;

import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";

import "../interfaces/IXensaAddressesProvider.sol";
import "../interfaces/IXensaMinter.sol";
import "./XensaToken.sol";

contract XensaMiner is XensaToken, IXensaMinter, Ownable {
    using SafeMath for uint256;
    bool private locked;

    modifier noReentrancy() {
        require(
            !locked,
            "Reentrant call."
        );
        locked = true;
        _;
        locked = false;
    }

    event MintDeposit(address indexed user, uint256 indexed pid, uint256 gid, uint256 amount, uint256 total);
    event MintWithdraw(address indexed user, uint256 indexed pid, uint256 gid, uint256 amount, uint256 total, uint256 received, uint256 fine);

    uint256 private _alloced = 0;
    
    uint liquidityPool = 3;
    uint constPoolCount = 4;

    uint256 depositWithdraw = 1;
    uint256 borrowRepay = 2;

    uint256 protectDurationBlocks = 2356360; 

    PoolInfo[] private poolInfo;    
    mapping(uint256 => uint256[]) private idxGroups;
    IXensaAddressesProvider ap;
    address private lp;

    mapping(uint256 => bool) private constPoolIsInit;
    struct stakeInfo {
        uint256 amount; 
        uint256 AVP; 
    }
    mapping(address => mapping(address=>stakeInfo)) private userStakeInfo;
    constructor(address addressAp) public XensaToken("XensaToken", "XENSA") {
	ap = IXensaAddressesProvider(addressAp); 
    }
    function setLp(address addressLP) public noReentrancy onlyOwner {
        lp = addressLP;
    }

    function mint(address _to, uint256 _amount) internal {
        XensaTokenMint(_to, _amount);
    }

    modifier onlyXensa {
        require(ap.getXensa() == msg.sender, "XensaToken: the caller must be xensa contract");
	_;
    }

    struct UserInfo {
        uint256 amount;
        uint256 lastWithdrawBlock;
        uint256 rewardDebt;
        uint256 protectAmount;
        uint256 mintPending;
        uint256 protectMintPending;
        uint256 receivedPerStake;
        uint256 PDA;
    }

    struct Group {
        uint256 allocPoint;
        uint256 totalAmount;  
        uint256 accPerShare;
        uint256 pricePerStake;
        mapping (address => UserInfo) users;
    }

    struct PoolInfo {
        uint256 poolCap;
        uint256 totalAllocPoint;
        uint256 startBlock;
        uint256 endBlock;
        uint256 bonusPerBlock;
        uint256 lockedTotal;
        bool ageout;
        mapping (uint256 =>Group) groups;
    }

    function poolLength() public view returns (uint256) {
        return poolInfo.length;
    }

    function createPool(uint256 _pid, uint256 _poolCap, uint256 _startBlock, uint256 _endBlock) public noReentrancy onlyOwner {
        require(_pid == poolLength(), "createPool: _pid fault");
        require(block.number < _endBlock && _endBlock > _startBlock , "createPool: Invailed block parameters");
        _poolCap = _poolCap.mul(1e18);
        require(_poolCap > 0, "createPool: cap fault");

	_alloced = _alloced.add(_poolCap);
        uint256 startBlock = block.number > _startBlock ? block.number : _startBlock;
        
        require(_endBlock > startBlock , "createPool: Invailed block parameters 2");
	uint256 _bonusPerBlock = _poolCap.div(_endBlock.sub(startBlock));

        poolInfo.push(PoolInfo({
            poolCap: _poolCap,
            totalAllocPoint: 0,
            startBlock: startBlock,
            endBlock: _endBlock,
            bonusPerBlock: _bonusPerBlock,
	    lockedTotal: 0,
            ageout: false
        }));
    }

    function setGroup(uint256 _pid, uint256 _gid, uint256 _allocPoint) public noReentrancy onlyOwner {
        require(_pid < poolLength(), "setGroup: _pid fault");
        require(constPoolIsInit[_pid] == false, "init failed");
        if (poolInfo[_pid].groups[_gid].allocPoint == 0){
            idxGroups[_pid].push(_gid);
        }
        poolInfo[_pid].totalAllocPoint = poolInfo[_pid].totalAllocPoint.sub(poolInfo[_pid].groups[_gid].allocPoint).add(_allocPoint);
        poolInfo[_pid].groups[_gid] = Group({
            allocPoint: _allocPoint,
            totalAmount: 0,
            accPerShare: 0,
            pricePerStake: 0
        });
	massUpdateGroups(_pid);
    }
    
    function getMultiplier(uint256 _from, uint256 _to, uint256 _start, uint256 _end) internal pure returns (uint256) {
        require(_from <= _to, "Block counting: ");
        require(_start <= _end, "Block counting: ");
        if (_to > _end) {
            _to = _end;
        } 
        if (_from < _start) {
            _from = _start;
        }

        if (_from >= _to) {
            return 0;
        }

        return _to.sub(_from);
    }
 
    function massUpdateGroups(uint256 _pid) internal {
        uint256 length = idxGroups[_pid].length;
        for (uint256 i = 0; i < length; ++i) {
            updateGroup(_pid, idxGroups[_pid][i]);
        }
    }
    
    function calculateMGR(uint256 point, uint256 base) internal pure returns (uint256 mgr) {
        mgr = 1e18;
        mgr = mgr.mul(point).div(base);
        
        uint256 z = mgr.add(1).div(2);
        uint256 y = mgr;
        while(z < y){
          y = z;
          z = mgr.div(z).add(z).div(2);
        }
        mgr = y.mul(75e7);
    }

    function updateUserProtectDuration(address userAddr, UserInfo storage u, uint256 amount, uint256 pending, uint256 poolPrice, bool unlockedOnly) internal returns(uint256 unlocked, uint256 flushCount) {
        if (block.number > u.PDA) {
            u.protectAmount = 0;
            u.protectMintPending = 0;
        }
        {
            uint256 pa = u.protectAmount.add(amount);
            if (pa > 0) {
                u.PDA = u.protectAmount.mul(u.PDA).add(amount.mul(block.number.add(protectDurationBlocks))).div(pa);
            }
        }
        u.lastWithdrawBlock = block.number;
        u.mintPending = u.mintPending.add(pending);
        if (u.protectAmount != 0) {
            u.protectMintPending = u.protectMintPending.add(pending.mul(u.protectAmount).div(u.amount));
        }
        u.amount = u.amount.add(amount);
        u.protectAmount = u.protectAmount.add(amount); 		
        if (amount == 0){ //withdraw 
            if (unlockedOnly) { 
                flushCount = u.mintPending.sub(u.protectMintPending).add(poolPrice);
                u.mintPending = u.protectMintPending;
            }else{
                unlocked = u.protectMintPending.mul(30).div(100); 
                flushCount = u.mintPending.sub(unlocked).add(poolPrice); 
                u.mintPending = 0;
                u.protectMintPending = 0;
            }
            if (flushCount > 0) {
                mint(address(this), flushCount);
                this.transfer(userAddr, flushCount);
            }
        }else{
                u.mintPending.add(poolPrice);
        }
    }

    function updateGroup(uint256 _pid, uint256 _gid) internal {
        PoolInfo storage pool = poolInfo[_pid];
        Group storage group = pool.groups[_gid];
        uint256 mgr = calculateMGR(group.totalAmount, pool.poolCap);
        group.accPerShare = pool.bonusPerBlock.mul(group.allocPoint).div(pool.totalAllocPoint).mul(mgr).div(1e18);
    }

    function getPoolInfo (uint256 _pid) public view returns (uint256 poolCap,
        uint256 totalAllocPoint,
        uint256 startBlock,
        uint256 endBlock,
        uint256 bonusPerBlock,
        uint256 lockedTotal) {
        PoolInfo storage pool = poolInfo[_pid];
        poolCap = pool.poolCap;
        totalAllocPoint = pool.totalAllocPoint;
        startBlock = pool.startBlock;
        endBlock = pool.endBlock;
        bonusPerBlock = pool.bonusPerBlock;
        lockedTotal = pool.lockedTotal;
    }
    function getGroupInfo(uint256 _pid, uint256 _gid) public view returns (uint256 gp, uint256 groupTotal, uint256 accPerShare){
        PoolInfo storage pool = poolInfo[_pid];
        Group storage group = pool.groups[_gid];
        gp = group.allocPoint;
        groupTotal = group.totalAmount;
        accPerShare = group.accPerShare;
    }

    function _deposit(uint256 _pid, uint256 _gid, address u, uint256 _amount) internal {
        if (_amount == 0) {
            return;
        }
        PoolInfo storage pool = poolInfo[_pid];
        if (pool.ageout) {
            return;
        }
        if (pool.endBlock < block.number) {
            pool.ageout = true;
            return;
        }
        Group storage group = pool.groups[_gid];
        UserInfo storage user = group.users[u];

        uint256 multiplier = getMultiplier(user.lastWithdrawBlock, block.number, pool.startBlock, pool.endBlock);
        uint256 pending = 0;
        if (group.totalAmount > 0) {
            pending = multiplier.mul(group.accPerShare).mul(user.amount).div(group.totalAmount);
        }
        group.totalAmount = group.totalAmount.add(_amount);
        updateGroup(_pid, _gid);

        uint256 protectPrice = userGainPrice(_pid, _gid, u); 
        updateUserProtectDuration(u, user, _amount, pending, protectPrice, true);
        pool.lockedTotal = pool.lockedTotal.sub(protectPrice); 

        emit MintDeposit(u, _pid, _gid, user.amount, group.totalAmount);
    }

    function _withdraw(uint256 _pid, uint256 _gid, address u, uint256 _amount, bool unlockedOnly) internal {
        uint256 fine = 0;
        uint256 unlockAmount = 0;
        uint256 flush = 0;
        PoolInfo storage pool = poolInfo[_pid];
        if (pool.ageout == false && pool.endBlock < block.number) {
            pool.ageout = true;
        }
        Group storage group = pool.groups[_gid];
        UserInfo storage user = group.users[u];
        if (!(group.totalAmount > 0)) {
            return;
        }
        require(user.amount >= _amount, "withdraw: not good");
        if (pool.endBlock < block.number){
            user.protectAmount = 0; 
            user.protectMintPending = 0;
        }
        unlockAmount = user.amount.sub(user.protectAmount); 
        require(!(unlockedOnly && unlockAmount<_amount) , "withdraw: unlocked balance not enough");

        uint256 multiplier = getMultiplier(user.lastWithdrawBlock, block.number, pool.startBlock, pool.endBlock);
        uint256 pending = multiplier.mul(group.accPerShare).mul(user.amount).div(group.totalAmount);
        uint256 protectPrice; 
        {
            protectPrice = userGainPrice(_pid, _gid, u); 
            if (_amount>0 && unlockAmount >= _amount) {
                unlockedOnly = true;
            }
        }
        (fine, flush) = updateUserProtectDuration(u, user, 0, pending, protectPrice, unlockedOnly);
        pool.lockedTotal = pool.lockedTotal.add(fine.div(3).mul(2)).sub(protectPrice); 
        user.amount = user.amount.sub(_amount);
        group.totalAmount = group.totalAmount.sub(_amount);
        if (fine > 0) {
            updatePricePerStake(_pid, fine.div(3).mul(2));
            mint(address(0xdead), fine.div(3));
        }

        if (user.protectAmount > user.amount){
            user.protectAmount = user.amount;
        }
        user.rewardDebt = user.rewardDebt.add(pending);
        if (!pool.ageout) {
            updateGroup(_pid, _gid);
        }

        emit MintWithdraw(msg.sender, _pid, _gid, _amount, group.totalAmount, flush, fine);
    }

    function pendingXensa(uint256 _pid, uint256 _gid, address _user) public view returns (uint256 amount, uint256 protectAmount, uint256 protectBlock, uint256 pending, uint256 protectMintPending, uint256 protectPrice, uint256 lockedTotal) {
        PoolInfo storage pool = poolInfo[_pid];
        Group storage group = pool.groups[_gid];
        UserInfo storage user = group.users[_user];
        if (group.totalAmount == 0) {
            return (0, 0, 0, 0, 0, 0, 0);
        }
        uint256 multiplier = getMultiplier(user.lastWithdrawBlock, block.number, pool.startBlock, pool.endBlock);
                   pending = multiplier.mul(group.accPerShare).mul(user.amount).div(group.totalAmount).add(user.mintPending);

        amount = user.amount;
        uint256 rate = _priceRate(pool, group, user);
        protectPrice = pool.lockedTotal.mul(rate).div(1e18); 
        if (block.number < user.PDA) {
            protectAmount = user.protectAmount;
            protectMintPending = multiplier.mul(group.accPerShare).mul(user.protectAmount).div(group.totalAmount).add(user.protectMintPending);
        }
        protectBlock = user.PDA;
        lockedTotal = pool.lockedTotal; 
    }

    function selectPool() internal view returns (uint256){
        for (uint i = constPoolCount; i<poolLength(); i++) {
            if (poolInfo[i].endBlock > block.number) {
                return i;
            }
        }
        return 0;
    }

    function getUserAmount(uint256 _gid, address _user) public view returns (uint256 amount, uint256 pending, uint256 protectPending, uint256 protectPriceTotal, uint256 lockedPriceTotal){
        if (poolLength() <= constPoolCount) {
            return (0, 0, 0, 0, 0);
        }
        if (_gid != depositWithdraw && _gid != borrowRepay) {
            return (0, 0, 0, 0, 0);
        }
        uint256 p;
        uint256 pm;
        uint256 pp;
        uint256 lt;
        for (uint i = liquidityPool; i<poolLength(); i++) {
            amount = amount.add(poolInfo[i].groups[_gid].users[_user].amount);
            (, , , p, pm,pp,lt) = pendingXensa(i, _gid, _user);
            pending = pending.add(p);
            protectPending = protectPending.add(pm);
            protectPriceTotal = protectPriceTotal.add(pp); 
            lockedPriceTotal = lockedPriceTotal.add(lt);
        }
    }

    function _priceRate(PoolInfo memory p, Group memory g, UserInfo memory u) internal view returns (uint256 rate) {
        if (g.totalAmount == 0) {
            return 0;
        }
        uint256 protectAmount = u.protectAmount;
        if (block.number > u.PDA) {
            protectAmount = 0;
        }
        rate = 1e18;
        rate = rate.mul(u.amount.sub(protectAmount)).mul(g.allocPoint).div(p.totalAllocPoint).div(g.totalAmount); 
    }

    function userGainPrice(uint256 _pid, uint256 _gid, address _u) internal returns (uint256 price) {
        PoolInfo storage p = poolInfo[_pid];
        Group storage g = p.groups[_gid];
        UserInfo storage u = g.users[_u]; 
        if (u.receivedPerStake >= g.pricePerStake) {
            return 0;
        }
        price = u.amount.mul(g.pricePerStake.sub(u.receivedPerStake)).div(1e18); 
        u.receivedPerStake = g.pricePerStake; 
        return price;  
    }

    function updatePricePerStake(uint256 _pid, uint256 amount) internal {
        uint256 input = amount.mul(1e18);
        uint256 length = idxGroups[_pid].length;
        for (uint256 i = 0; i < length; ++i) {
            updateGroupStake(_pid, idxGroups[_pid][i], input);
        }
    }

    function updateGroupStake(uint256 _pid, uint256 _gid, uint256 amount) internal {
        PoolInfo storage pool = poolInfo[_pid];
        Group storage group = pool.groups[_gid];
        if (group.totalAmount > 0) {
            group.pricePerStake = group.pricePerStake.add(amount.mul(group.allocPoint).div(pool.totalAllocPoint).div(group.totalAmount));
        }
    }

    function priceRate(address u) external view returns (uint256 rate) {
        PoolInfo storage pool = poolInfo[liquidityPool];
        uint256 _rate;
        Group storage group = pool.groups[depositWithdraw];
        UserInfo storage user = group.users[u];
        if (user.amount != 0) {
            _rate = _priceRate(pool, group, user);
            rate = rate.add(_rate);
        }
    }

    function mintXensaToken(address _reserve, address _user, uint256 _gid, uint256 _amount, uint256 _price) external noReentrancy onlyXensa {
        if (_amount == 0 || _price == 0) {
            return;
        }
        stakeInfo storage s = userStakeInfo[_user][_reserve];
        s.AVP = s.AVP.mul(s.amount).add(_price.mul(_amount)).div(s.amount.add(_amount));
        s.amount = s.amount.add(_amount);
        uint256 workload = _amount.mul(_price);
        _mintXensaToken(_reserve, _user, _gid, workload); 
    }

    function _mintXensaToken(address _reserve, address _user, uint256 _gid, uint256 _amount) internal {
        if (_amount == 0) {
            return;
        }
        require(poolLength() >= constPoolCount, "minXensaToken: Invailed pools");
        require(_gid == depositWithdraw || _gid == borrowRepay, "minXensaToken: Invailed action");
        if (_reserve == lp) {
            _deposit(liquidityPool, _gid, _user, _amount); 
            return;
        }
        uint256 _pid = selectPool();
        if (!(_pid < constPoolCount)){
            _deposit(_pid, _gid, _user, _amount); 
        }
    }

    function withdrawXensaToken(address _reserve, address _user, uint256 _gid, uint256 _amount, bool unlockedOnly) external noReentrancy onlyXensa {
        if (_amount == 0) {
            return;
        }
        stakeInfo storage s = userStakeInfo[_user][_reserve];
        require(s.amount>=_amount, "Not enough reserve to withdraw.");
        s.amount = s.amount.sub(_amount);
        uint256 workload = _amount.mul(s.AVP);
        _withdrawXensaToken(_user, _gid, workload, unlockedOnly); 
    }

    function _withdrawXensaToken(address _user, uint256 _gid, uint256 amount, bool unlockedOnly) internal {
        if (amount == 0) {
            return;
        }
        require(poolLength() > constPoolCount, "minXensaToken: Invailed pools");
        require(_gid == depositWithdraw || _gid == borrowRepay, "minXensaToken: Invailed action");
        
        uint256 _amount;
        (_amount, , , ,) = getUserAmount(_gid, _user);
        if (amount > _amount) {
            amount = _amount;
        }
        for (uint i = poolLength()-1; i >= liquidityPool; i--) {
            _amount = poolInfo[i].groups[_gid].users[_user].amount;
            if (_amount > 0){
               if (amount > _amount) {
                    _withdraw(i, _gid, _user, _amount, unlockedOnly);
                    amount = amount.sub(_amount);
               } else {
                    _withdraw(i, _gid, _user, amount, unlockedOnly);
                    amount = 0;
               }
            }
            if (amount == 0) {
                return;
            }
        }
    }

    function _withdrawPendingXensaToken(uint256 _gid, bool unlockedOnly) public {
        require(poolLength() > constPoolCount, "minXensaToken: Invailed pools");
        require(_gid == depositWithdraw || _gid == borrowRepay, "minXensaToken: Invailed action");
        for (uint i = poolLength()-1; i >=  liquidityPool; i--) {
            if (poolInfo[i].groups[_gid].users[msg.sender].lastWithdrawBlock < block.number) {
                _withdraw(i, _gid, msg.sender, 0, unlockedOnly);
            }
        }
    }

    function withdrawPendingXensaToken(bool unlockedOnly) public {
        _withdrawPendingXensaToken(1, unlockedOnly); 
        _withdrawPendingXensaToken(2, unlockedOnly); 
    }

    function setPoolInited(uint256 _pid) public noReentrancy onlyOwner {
        constPoolIsInit[_pid] = true;
    }

    function deposit(uint256 _pid, uint256 _gid, address u, uint256 _amount) external noReentrancy onlyOwner {
        require(_pid < liquidityPool, "only for const pool");
        require(constPoolIsInit[_pid] == false, "init failed");
        constPoolIsInit[_pid] = true;
        _deposit(_pid, _gid, u, _amount);
    }

    function withdraw(uint256 _pid, uint256 _gid, address u, uint256 _amount) external noReentrancy onlyOwner {
        require(_pid < liquidityPool, "only for const pool" );
        _withdraw(_pid, _gid, u, _amount, true);
    }
}

