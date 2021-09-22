pragma solidity ^0.5.0;

import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "../libraries/openzeppelin-upgradeability/InitializableAdminUpgradeabilityProxy.sol";

import "./AddressStorage.sol";
import "../interfaces/IXensaAddressesProvider.sol";

/**
* @title XensaAddressesProvider contract
* @notice Is the main registry of the protocol. All the different components of the protocol are accessible
* through the addresses provider.
* @author Xensa
**/

contract XensaAddressesProvider is Ownable, IXensaAddressesProvider, AddressStorage {
    //events
    event XensaUpdated(address indexed newAddress);
    event XensaCoreUpdated(address indexed newAddress);
    event XensaParametersProviderUpdated(address indexed newAddress);
    event XensaManagerUpdated(address indexed newAddress);
    event XensaConfiguratorUpdated(address indexed newAddress);
    event XensaLiquidationManagerUpdated(address indexed newAddress);
    event XensaDataProviderUpdated(address indexed newAddress);
    event EthereumAddressUpdated(address indexed newAddress);
    event PriceOracleUpdated(address indexed newAddress);
    event InterestRateOracleUpdated(address indexed newAddress);
    event FeeProviderUpdated(address indexed newAddress);
    event TokenDistributorUpdated(address indexed newAddress);
    event XensaMinterUpdated(address indexed newAddress);

    event ProxyCreated(bytes32 id, address indexed newAddress);

    bytes32 private constant XENSA = "XENSA";
    bytes32 private constant XENSA_CORE = "XENSA_CORE";
    bytes32 private constant XENSA_CONFIGURATOR = "XENSA_CONFIGURATOR";
    bytes32 private constant XENSA_PARAMETERS_PROVIDER = "PARAMETERS_PROVIDER";
    bytes32 private constant XENSA_MANAGER = "XENSA_MANAGER";
    bytes32 private constant XENSA_LIQUIDATION_MANAGER = "LIQUIDATION_MANAGER";
    bytes32 private constant DATA_PROVIDER = "DATA_PROVIDER";
    bytes32 private constant ETHEREUM_ADDRESS = "ETHEREUM_ADDRESS";
    bytes32 private constant PRICE_ORACLE = "PRICE_ORACLE";
    bytes32 private constant INTEREST_RATE_ORACLE = "INTEREST_RATE_ORACLE";
    bytes32 private constant FEE_PROVIDER = "FEE_PROVIDER";
    bytes32 private constant WALLET_BALANCE_PROVIDER = "WALLET_BALANCE_PROVIDER";
    bytes32 private constant TOKEN_DISTRIBUTOR = "TOKEN_DISTRIBUTOR";
    bytes32 private constant XENSA_MINTER = "XENSA_MINTER ";


    /**
    * @dev returns the address of the Xensa proxy
    * @return the xensa proxy address
    **/
    function getXensa() public view returns (address) {
        return getAddress(XENSA);
    }


    /**
    * @dev updates the implementation of the xensa
    * @param _xensa the new xensa implementation
    **/
    function setXensaImpl(address _xensa) public onlyOwner {
        updateImplInternal(XENSA, _xensa);
        emit XensaUpdated(_xensa);
    }

    /**
    * @dev returns the address of the XensaCore proxy
    * @return the xensa core proxy address
     */
    function getXensaCore() public view returns (address payable) {
        address payable core = address(uint160(getAddress(XENSA_CORE)));
        return core;
    }

    /**
    * @dev updates the implementation of the xensa core
    * @param _xensaCore the new xensa core implementation
    **/
    function setXensaCoreImpl(address _xensaCore) public onlyOwner {
        updateImplInternal(XENSA_CORE, _xensaCore);
        emit XensaCoreUpdated(_xensaCore);
    }

    /**
    * @dev returns the address of the XensaConfigurator proxy
    * @return the xensa configurator proxy address
    **/
    function getXensaConfigurator() public view returns (address) {
        return getAddress(XENSA_CONFIGURATOR);
    }

    /**
    * @dev updates the implementation of the xensa configurator
    * @param _configurator the new xensa configurator implementation
    **/
    function setXensaConfiguratorImpl(address _configurator) public onlyOwner {
        updateImplInternal(XENSA_CONFIGURATOR, _configurator);
        emit XensaConfiguratorUpdated(_configurator);
    }

    /**
    * @dev returns the address of the XensaDataProvider proxy
    * @return the xensa data provider proxy address
     */
    function getXensaDataProvider() public view returns (address) {
        return getAddress(DATA_PROVIDER);
    }

    /**
    * @dev updates the implementation of the xensa data provider
    * @param _provider the new xensa data provider implementation
    **/
    function setXensaDataProviderImpl(address _provider) public onlyOwner {
        updateImplInternal(DATA_PROVIDER, _provider);
        emit XensaDataProviderUpdated(_provider);
    }

    /**
    * @dev returns the address of the XensaParametersProvider proxy
    * @return the address of the xensa parameters provider proxy
    **/
    function getXensaParametersProvider() public view returns (address) {
        return getAddress(XENSA_PARAMETERS_PROVIDER);
    }

    /**
    * @dev updates the implementation of the xensa parameters provider
    * @param _parametersProvider the new xensa parameters provider implementation
    **/
    function setXensaParametersProviderImpl(address _parametersProvider) public onlyOwner {
        updateImplInternal(XENSA_PARAMETERS_PROVIDER, _parametersProvider);
        emit XensaParametersProviderUpdated(_parametersProvider);
    }

    /**
    * @dev returns the address of the FeeProvider proxy
    * @return the address of the Fee provider proxy
    **/
    function getFeeProvider() public view returns (address) {
        return getAddress(FEE_PROVIDER);
    }

    /**
    * @dev updates the implementation of the FeeProvider proxy
    * @param _feeProvider the new xensa fee provider implementation
    **/
    function setFeeProviderImpl(address _feeProvider) public onlyOwner {
        updateImplInternal(FEE_PROVIDER, _feeProvider);
        emit FeeProviderUpdated(_feeProvider);
    }

    /**
    * @dev returns the address of the XensaLiquidationManager. Since the manager is used
    * through delegateCall within the Xensa contract, the proxy contract pattern does not work properly hence
    * the addresses are changed directly.
    * @return the address of the xensa liquidation manager
    **/

    function getXensaLiquidationManager() public view returns (address) {
        return getAddress(XENSA_LIQUIDATION_MANAGER);
    }

    /**
    * @dev updates the address of the xensa liquidation manager
    * @param _manager the new xensa liquidation manager address
    **/
    function setXensaLiquidationManager(address _manager) public onlyOwner {
        _setAddress(XENSA_LIQUIDATION_MANAGER, _manager);
        emit XensaLiquidationManagerUpdated(_manager);
    }

    /**
    * @dev the functions below are storing specific addresses that are outside the context of the protocol
    * hence the upgradable proxy pattern is not used
    **/


    function getXensaManager() public view returns (address) {
        return getAddress(XENSA_MANAGER);
    }

    function setXensaManager(address _xensaManager) public onlyOwner {
        _setAddress(XENSA_MANAGER, _xensaManager);
        emit XensaManagerUpdated(_xensaManager);
    }

    function getPriceOracle() public view returns (address) {
        return getAddress(PRICE_ORACLE);
    }

    function setPriceOracle(address _priceOracle) public onlyOwner {
        _setAddress(PRICE_ORACLE, _priceOracle);
        emit PriceOracleUpdated(_priceOracle);
    }

    function getInterestRateOracle() public view returns (address) {
        return getAddress(INTEREST_RATE_ORACLE);
    }

    function setInterestRateOracle(address _interestRateOracle) public onlyOwner {
        _setAddress(INTEREST_RATE_ORACLE, _interestRateOracle);
        emit InterestRateOracleUpdated(_interestRateOracle);
    }

    function getTokenDistributor() public view returns (address) {
        return getAddress(TOKEN_DISTRIBUTOR);
    }

    function setTokenDistributor(address _tokenDistributor) public onlyOwner {
        _setAddress(TOKEN_DISTRIBUTOR, _tokenDistributor);
        emit TokenDistributorUpdated(_tokenDistributor);
    }

    function getXensaMinter() public view returns (address) {
        return getAddress(XENSA_MINTER);
    }

    function setXensaMinter(address _xensaMinter) public onlyOwner {
        _setAddress(XENSA_MINTER, _xensaMinter);
        emit XensaMinterUpdated(_xensaMinter);
    }

    /**
    * @dev internal function to update the implementation of a specific component of the protocol
    * @param _id the id of the contract to be updated
    * @param _newAddress the address of the new implementation
    **/
    function updateImplInternal(bytes32 _id, address _newAddress) internal {
        address payable proxyAddress = address(uint160(getAddress(_id)));

        InitializableAdminUpgradeabilityProxy proxy = InitializableAdminUpgradeabilityProxy(proxyAddress);
        bytes memory params = abi.encodeWithSignature("initialize(address)", address(this));

        if (proxyAddress == address(0)) {
            proxy = new InitializableAdminUpgradeabilityProxy();
            proxy.initialize(_newAddress, address(this), params);
            _setAddress(_id, address(proxy));
            emit ProxyCreated(_id, address(proxy));
        } else {
            proxy.upgradeToAndCall(_newAddress, params);
        }

    }
}
