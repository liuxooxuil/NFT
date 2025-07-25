// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract Shared1155TokenSSSS is AccessControl, Pausable, ERC1155, ERC1155Burnable, ERC1155URIStorage, ERC1155Supply {
    using Counters for Counters.Counter;
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    Counters.Counter private _tokenIdCounter;
    Counters.Counter private _collectionIdCounter;

    string public name;

    mapping(uint256 => Collection) public collections; // 项目集映射
    mapping(uint256 => CollectionData) public collectionDatas; // NFT 数据映射
    uint256[] public collectionIds; // 存储所有项目集 ID
    uint256[] public tokenIds; // 存储所有 NFT ID

    event CollectionURIMinted(
        address indexed account,
        uint256 tokenId,
        bytes32 collectionURI,
        uint256 amount
    );

    event CollectionCreated(
        uint256 indexed collectionId,
        string collectionName,
        string collectionDescription
    );

    struct Collection {
        uint256 id;
        string name;        // 项目集名称
        string description; // 项目集描述
        uint256 totalSupply; // 项目集内 NFT 总供应量
    }

    struct CollectionData {
        bytes32 cid;
        uint256 collectionId; // 关联的项目集 ID
    }

    constructor() ERC1155("") {
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _grantRole(MINTER_ROLE, _msgSender());
        name = "Carbon Credit Asset";
    }

    function supportsInterface(bytes4 interfaceId) public view override(AccessControl, ERC1155) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function uri(uint256 tokenId) public view override(ERC1155, ERC1155URIStorage) returns (string memory) {
        return super.uri(tokenId);
    }

    function setTokenURI(uint256 tokenId, string memory newURI) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(totalSupply(tokenId) > 0, "Shared1155Token: URI set of nonexistent token");
        _setURI(tokenId, newURI);
    }

    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    function mint(address account, uint256 id, uint256 amount, bytes memory data) external onlyRole(MINTER_ROLE) {
        _mint(account, id, amount, data);
    }

    function createCollection(string memory collectionName, string memory collectionDescription) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _collectionIdCounter.increment();
        uint256 collectionId = _collectionIdCounter.current();

        collections[collectionId] = Collection(collectionId, collectionName, collectionDescription, 0);
        collectionIds.push(collectionId);
        emit CollectionCreated(collectionId, collectionName, collectionDescription);
    }

    function safeCast(
        string memory tokenURI,
        address to,
        uint256 amount,
        bytes32 cid,
        uint256 collectionId
    ) external onlyRole(MINTER_ROLE) {
        require(collections[collectionId].id != 0, "Shared1155Token: Collection does not exist");

        _tokenIdCounter.increment();
        uint256 tokenId = _tokenIdCounter.current();

        _mint(to, tokenId, amount, "");
        _setURI(tokenId, tokenURI);

        CollectionData storage collectionData = collectionDatas[tokenId];
        collectionData.cid = cid;
        collectionData.collectionId = collectionId;

        collections[collectionId].totalSupply += amount;
        tokenIds.push(tokenId);

        emit CollectionURIMinted(to, tokenId, cid, amount);
    }

    function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data) external onlyRole(MINTER_ROLE) {
        _mintBatch(to, ids, amounts, data);
    }

    function _update(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values
    ) internal override(ERC1155, ERC1155Supply) whenNotPaused {
        super._update(from, to, ids, values);
    }

    function getCollectionData(uint256 tokenId) external view returns (CollectionData memory) {
        require(totalSupply(tokenId) > 0, "Shared1155Token: Nonexistent token");
        return collectionDatas[tokenId];
    }

    function getCollection(uint256 collectionId) external view returns (Collection memory) {
        require(collections[collectionId].id != 0, "Shared1155Token: Collection does not exist");
        return collections[collectionId];
    }

    function getAllCollections() external view returns (Collection[] memory) {
        Collection[] memory allCollections = new Collection[](collectionIds.length);
        for (uint256 i = 0; i < collectionIds.length; i++) {
            allCollections[i] = collections[collectionIds[i]];
        }
        return allCollections;
    }

    function getAllCollectionDatas() external view returns (CollectionData[] memory) {
        CollectionData[] memory allDatas = new CollectionData[](tokenIds.length);
        for (uint256 i = 0; i < tokenIds.length; i++) {
            allDatas[i] = collectionDatas[tokenIds[i]];
        }
        return allDatas;
    }
}