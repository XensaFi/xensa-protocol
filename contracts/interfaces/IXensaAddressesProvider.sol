pragma solidity ^0.5.0;

/**
@title IXensaAddressesProvider interface
@notice provides the interface to fetch the XensaCore address
 */

contract IXensaAddressesProvider {

    function getXensa() public view returns (address);
    function setXensaImpl(address _pool) public;

    function getXensaCore() public view returns (address payable);
    function setXensaCoreImpl(address _xensaCore) public;

    function getXensaConfigurator() public view returns (address);
    function setXensaConfiguratorImpl(address _configurator) public;

    function getXensaDataProvider() public view returns (address);
    function setXensaDataProviderImpl(address _provider) public;

    function getXensaParametersProvider() public view returns (address);
    function setXensaParametersProviderImpl(address _parametersProvider) public;

    function getTokenDistributor() public view returns (address);
    function setTokenDistributor(address _tokenDistributor) public;


    function getFeeProvider() public view returns (address);
    function setFeeProviderImpl(address _feeProvider) public;

    function getXensaLiquidationManager() public view returns (address);
    function setXensaLiquidationManager(address _manager) public;

    function getXensaManager() public view returns (address);
    function setXensaManager(address _xensaManager) public;

    function getPriceOracle() public view returns (address);
    function setPriceOracle(address _priceOracle) public;

    function getInterestRateOracle() public view returns (address);
    function setInterestRateOracle(address _interestRateOracle) public;

}
