// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";

contract Shared1155TokenSSSS is AccessControl, Pausable, ERC1155, ERC1155Burnable, ERC1155URIStorage, ERC1155Supply, IERC1155Receiver {
    using Counters for Counters.Counter;
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant COLLECTION_CREATOR_ROLE = keccak256("COLLECTION_CREATOR_ROLE");

    Counters.Counter private _tokenIdCounter;
    Counters.Counter private _collectionIdCounter;

    string public name;

    mapping(uint256 => Collection) public collections;
    mapping(uint256 => CollectionData) public collectionDatas;
    uint256[] public collectionIds;
    uint256[] public tokenIds;

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
        string suffix;
    }

    struct CollectionData {
        bytes32 cid;
        uint256 collectionId;
    }

    struct NFTDetails {
        uint256 tokenId;
        uint256 amount;
        string uri;
        CollectionData collectionData;
    }

    constructor() ERC1155("") {
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _grantRole(MINTER_ROLE, _msgSender());
        _grantRole(COLLECTION_CREATOR_ROLE, _msgSender());
        name = "Carbon Credit Asset";
        // 授权合约管理自身持有的所有 NFT
        _setApprovalForAll(address(this), address(this), true);
    }

    function supportsInterface(bytes4 interfaceId) public view override(IERC165, AccessControl, ERC1155) returns (bool) {
        return interfaceId == type(IERC1155Receiver).interfaceId || super.supportsInterface(interfaceId);
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
        uint256 amount,
        bytes32 cid,
        string memory suffix
    ) external onlyRole(MINTER_ROLE) {
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

        _mint(address(this), tokenId, amount, "");
        _setURI(tokenId, tokenURI);

        CollectionData storage collectionData = collectionDatas[tokenId];
        collectionData.cid = cid;
        collectionData.collectionId = collectionId;

        tokenIds.push(tokenId);

        emit CollectionURIMinted(address(this), tokenId, cid, amount);
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
                delete collections[id];
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

    // 转移逻辑
    function transferERC20(
        address tokenAddress,
        address to,
        uint256 amount,
        string memory targetURI
    // ) external onlyRole(MINTER_ROLE) {
    ) external {
        require(to != address(0), "Shared1155Token: Invalid recipient address");
        require(amount > 0, "Shared1155Token: Transfer amount must be greater than 0");

        // 执行 ERC20 转账
        IERC20 token = IERC20(tokenAddress);
        require(token.balanceOf(msg.sender) >= amount, "Shared1155Token: Insufficient ERC20 balance");
        require(token.allowance(msg.sender, address(this)) >= amount, "Shared1155Token: Insufficient ERC20 allowance");
        token.transferFrom(msg.sender, to, amount);

        // 查找 URI 匹配的 tokenId
        uint256 tokenId = 0;
        for (uint256 i = 0; i < tokenIds.length; i++) {
            if (keccak256(bytes(uri(tokenIds[i]))) == keccak256(bytes(targetURI))) {
                tokenId = tokenIds[i];
                break;
            }
        }
        require(tokenId != 0, "Shared1155Token: NFT with specified URI does not exist");
        require(balanceOf(address(this), tokenId) >= 1, "Shared1155Token: Insufficient NFT balance");

        // 转移 NFT（固定数量为 1）
        safeTransferFrom(address(this), to, tokenId, 1, "");
    }

    function getContractNFTs() external view returns (NFTDetails[] memory) {
        uint256 validCount = 0;
        for (uint256 i = 0; i < tokenIds.length; i++) {
            if (balanceOf(address(this), tokenIds[i]) > 0) {
                validCount++;
            }
        }

        NFTDetails[] memory nfts = new NFTDetails[](validCount);
        uint256 index = 0;

        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];
            uint256 amount = balanceOf(address(this), tokenId);
            if (amount > 0) {
                nfts[index] = NFTDetails({
                    tokenId: tokenId,
                    amount: amount,
                    uri: uri(tokenId),
                    collectionData: collectionDatas[tokenId]
                });
                index++;
            }
        }

        return nfts;
    }

    function onERC1155Received(
        address operator,
        address from,
        uint256 id,
        uint256 value,
        bytes calldata data
    ) external override returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address operator,
        address from,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    ) external override returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }

    // 根据 URI 转移 NFT
    function transferNFTByURI(
        address to,
        string memory targetURI,
        uint256 amount
    ) external {
        require(to != address(0), "Shared1155Token: Invalid recipient address");
        require(amount > 0, "Shared1155Token: Transfer amount must be greater than 0");

        // 查找 URI 匹配的 tokenId
        uint256 tokenId = 0;
        for (uint256 i = 0; i < tokenIds.length; i++) {
            if (keccak256(bytes(uri(tokenIds[i]))) == keccak256(bytes(targetURI))) {
                tokenId = tokenIds[i];
                break;
            }
        }
        require(tokenId != 0, "Shared1155Token: NFT with specified URI does not exist");
        require(balanceOf(address(this), tokenId) >= amount, "Shared1155Token: Insufficient NFT balance");

        // 转移 NFT
        safeTransferFrom(address(this), to, tokenId, amount, "");
    }
}