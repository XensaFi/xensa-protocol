pragma solidity 0.6.11;
pragma experimental ABIEncoderV2;

import "openzeppelin-solidity/contracts/access/Ownable.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";

interface IStdReference {
    function registerRequesterViewer() external;
    function put(bytes calldata message, bytes calldata signature) external returns (string memory);
    function put(bytes[] calldata messages, bytes[] calldata signatures) external returns (string[] memory keys);
    function latestRoundData(string calldata priceType, address dataSource) external view returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);
    function get(string calldata priceType, address source) external view returns (uint256 price, uint256 timestamp);
    function getOffchain(string calldata priceType, address source) external view returns (uint256 price, uint256 timestamp);
    function getCumulativePrice(string calldata priceType, address source) external view returns (uint256 cumulativePrice,uint32 timestamp);
    function changeSourceRecipient(address _recipient) external;
    function changeFeederRecipient(address _recipient) external;
    function postMining(address requester, bytes calldata message, bytes calldata signature) external;
    function transferCredit(uint256 amount, address to) external;
}

interface IERC20Symbol {
    function symbol() external view returns (string memory);
}

interface IPriceOracleGetter {
    /***********
    @dev returns the asset price in ETH
     */
    function getAssetPrice(address _asset) external view returns (uint256);
}

contract OKOracle is IPriceOracleGetter, Ownable {
    using SafeMath for uint256;
    event AssetSourceDeleted(address indexed asset);
    event AssetSourceUpdated(address indexed asset, string indexed symbol);
    event FallbackOracleUpdated(address indexed fallbackOracle);
    IStdReference ref;

    string quote; 
    IPriceOracleGetter private fallbackOracle;
    mapping(address => string) private assetsSources;
    address private baseAsset;
    address private source;

    constructor(IStdReference _ref, address _source, string memory _quote, address _fallbackOracle, address _baseAsset) public {
        ref = _ref;
        quote = _quote;
        baseAsset = _baseAsset;
        internalSetFallbackOracle(_fallbackOracle);
        source = _source;
    }

    function internalSetFallbackOracle(address _fallbackOracle) internal {
        fallbackOracle = IPriceOracleGetter(_fallbackOracle);
        emit FallbackOracleUpdated(_fallbackOracle);
    }

    function setAssetSource(address _asset, string calldata _symbol) external onlyOwner {
        internalSetAssetsSource(_asset, _symbol);
    }

    function unsetAssetSource(address _asset) external onlyOwner {
        internalUnSetAssetsSource(_asset);
    }

    function internalSetAssetsSource(address _asset, string calldata _symbol) internal {
        assetsSources[_asset] = _symbol;
        emit AssetSourceUpdated(_asset, _symbol);
    }

    function internalUnSetAssetsSource(address _asset) internal {
        delete(assetsSources[_asset]);
        emit AssetSourceDeleted(_asset);
    }

    function getLatestPrice(string memory priceType) public view returns (uint256)
    {
        (uint256  value, ) = ref.get(priceType, source);
        return value;
    }

    function getBasePrice() public view returns (uint256){
        uint256 values = getLatestPrice(quote); 
        return values;
    }

    function getAssetPrice(address _asset) override external view returns (uint256){
        if (_asset == baseAsset) {
            return 1 ether;
        }
        string memory regSymbol = assetsSources[_asset];
        if (bytes(regSymbol).length == 0) {
            return IPriceOracleGetter(fallbackOracle).getAssetPrice(_asset);
        }
        uint256 values = getLatestPrice(regSymbol); 
        uint256 baseValues = getBasePrice(); 
        return values.mul(1e18).div(baseValues);
    }
}
