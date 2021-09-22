pragma solidity ^0.5.0;
interface IXensaMinter {
    function mintXensaToken(address reserve, address _user,  uint256 _gid, uint256 _amount, uint256 _price) external; 
    function withdrawXensaToken(address _reserve, address _user, uint256 _gid, uint256 amount, bool unlockedOnly) external; 
}
