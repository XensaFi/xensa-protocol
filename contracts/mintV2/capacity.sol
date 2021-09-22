pragma solidity ^0.5.0;

import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";

contract capacity is Ownable {
    using SafeMath for uint256;
    address private _miner;
    bool private locked;
    uint256 private _total;         
    uint256 private _halfDuring;
    uint256 private _startBlock;
    uint256 private _amountPerBlock;
    uint256 private _lastUpdate;

    modifier noReentrancy() {
        require(
            !locked,
            "Reentrant call."
        );
        locked = true;
        _;
        locked = false;
    }

    function onlyMiner() internal view {
        require(msg.sender == _miner,"Reentrant call.");
    }

    function setMiner(address addressMiner) public noReentrancy onlyOwner {
        _miner = addressMiner;
    }

    constructor(uint256 total, uint256 startBlock, uint256 halfDuring) public {
        _total = total;
        _halfDuring = halfDuring;
        _startBlock = startBlock;
        _lastUpdate = startBlock;
        _amountPerBlock = total.div(2).div(_halfDuring);
    }

    function newInput() public noReentrancy returns (uint256 amount){
        onlyMiner();
        if (block.number <= _lastUpdate) {
            return 0;
        }
        uint256 slide;
        if (block.number < _startBlock.add(_halfDuring)) {
            slide = block.number; 
        }else{
            slide = _startBlock.add(_halfDuring); 
        }
        
        amount = amount.add(slide.sub(_lastUpdate).mul(_amountPerBlock));
        _lastUpdate = slide; 

        for (;block.number>_startBlock.add(_halfDuring);) {
            _startBlock = _startBlock.add(_halfDuring);
            _amountPerBlock = _amountPerBlock.div(2);

            if (block.number < _startBlock.add(_halfDuring)) {
                slide = block.number; 
            }else{
                slide = _startBlock.add(_halfDuring); 
            }

            amount = amount.add(slide.sub(_lastUpdate).mul(_amountPerBlock));
            _lastUpdate = slide; 
        }
        return amount;
    }
}
