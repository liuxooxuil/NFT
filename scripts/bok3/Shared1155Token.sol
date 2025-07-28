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
    bytes32 public constant COLLECTION_CREATOR_ROLE = keccak256("COLLECTION_CREATOR_ROLE");

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
        string suffix
    );

    event CollectionDeleted(
        uint256 indexed collectionId,
        string suffix
    );

    struct Collection {
        uint256 id;
        string suffix; // 保存后缀
    }

    struct CollectionData {
        bytes32 cid;
        uint256 collectionId; // 关联的项目集 ID
    }

    constructor() ERC1155("") {
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _grantRole(MINTER_ROLE, _msgSender());
        _grantRole(COLLECTION_CREATOR_ROLE, _msgSender());
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

    function createCollection(string memory suffix) external onlyRole(COLLECTION_CREATOR_ROLE) {
        // 查重逻辑
        for (uint256 i = 0; i < collectionIds.length; i++) {
            uint256 id = collectionIds[i];
            if (keccak256(bytes(collections[id].suffix)) == keccak256(bytes(suffix))) {
                revert("Shared1155Token: Duplicate suffix detected");
            }
        }

        _collectionIdCounter.increment();
        uint256 collectionId = _collectionIdCounter.current();

        collections[collectionId] = Collection(collectionId, suffix);
        collectionIds.push(collectionId);
        emit CollectionCreated(collectionId, suffix);
    }

    function safeCast(
        string memory tokenURI,
        address to,
        uint256 amount,
        bytes32 cid,
        string memory suffix
    ) external onlyRole(MINTER_ROLE) {
        // 查找与 suffix 匹配的 collectionId
        uint256 collectionId = 0;
        for (uint256 i = 0; i < collectionIds.length; i++) {
            if (keccak256(bytes(collections[collectionIds[i]].suffix)) == keccak256(bytes(suffix))) {
                collectionId = collections[collectionIds[i]].id;
                break;
            }
        }
        require(collectionId != 0, "Shared1155Token: Collection with suffix does not exist");

        _tokenIdCounter.increment();
        uint256 tokenId = _tokenIdCounter.current();

        _mint(to, tokenId, amount, "");
        _setURI(tokenId, tokenURI);

        CollectionData storage collectionData = collectionDatas[tokenId];
        collectionData.cid = cid;
        collectionData.collectionId = collectionId;

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

    function grantRoleTo(bytes32 role, address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(role, account);
    }

    function getCollectionSuffix(uint256 collectionId) external view returns (string memory) {
        require(collections[collectionId].id != 0, "Shared1155Token: Collection does not exist");
        return collections[collectionId].suffix;
    }

    function deleteCollectionBySuffix(string memory suffix) external onlyRole(DEFAULT_ADMIN_ROLE) {
        for (uint256 i = 0; i < collectionIds.length; i++) {
            uint256 id = collectionIds[i];
            if (keccak256(bytes(collections[id].suffix)) == keccak256(bytes(suffix))) {
                // 删除项目集
                delete collections[id];
                // 从 collectionIds 数组中移除
                if (i < collectionIds.length - 1) {
                    collectionIds[i] = collectionIds[collectionIds.length - 1];
                }
                collectionIds.pop();
                emit CollectionDeleted(id, suffix);
                return;
            }
        }
        revert("Shared1155Token: Collection with suffix not found");
    }
}