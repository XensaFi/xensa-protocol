pragma solidity ^0.5.0;

import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-solidity/contracts/token/ERC20/ERC20Detailed.sol";

/**
 * @title Xensa ERC20 XensaToken
 *
 * @dev Implementation of the interest bearing token for the DLP protocol.
 */
contract XensaToken is ERC20, ERC20Detailed {
    uint256 private _cap = 200000000e18;
    uint256 private _supply = 0;
    constructor(
        string memory _name,
        string memory _symbol
    ) public ERC20Detailed(_name, _symbol, 18) {

    }
    function XensaTokenMint(address _to, uint256 _amount) internal {
        require(_supply.add(_amount) <= _cap, "Xensa cap exceeded");
        _supply = _supply.add(_amount);
        _mint(_to, _amount);
    }

    function totalSupply() public view returns (uint256) {
        return _supply;
    }
    function cap() public view returns (uint256) {
        return _cap;
    }
}
