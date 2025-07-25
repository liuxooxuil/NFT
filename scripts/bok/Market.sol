// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts@4.9.3/access/Ownable.sol";
import "@openzeppelin/contracts@4.9.3/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts@4.9.3/interfaces/IERC721.sol";
import "@openzeppelin/contracts@4.9.3/interfaces/IERC1155.sol";
import "@openzeppelin/contracts@4.9.3/interfaces/IERC2981.sol";
import "@openzeppelin/contracts@4.9.3/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts@4.9.3/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts@4.9.3/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts@4.9.3/utils/Address.sol"; // 导入 Address 库

/// nft交易
contract Market is Ownable, ReentrancyGuard, ERC721Holder, ERC1155Holder {
    using SafeERC20 for IERC20;
    using Address for address payable; // 使用 Address 库

    bytes4 public constant INTERFACE_ID_ERC721 = 0x80ac58cd;
    bytes4 public constant INTERFACE_ID_ERC1155 = 0xd9b67a26;
    bytes4 public constant INTERFACE_ID_ERC2981 = 0x2a55205a;

    uint256 public constant FEE_DENOMINATOR = 10000;

    uint256 public fee = 250;

    address public payee;

    struct Collectible {
        bytes32 category;
        address seller;
        address collection;
        uint256 tokenId;
        uint256 amount;
        address currency;
        uint256 price;
    }

    mapping(bytes32 => Collectible) public collectibles;
    mapping(bytes32 => uint256) public collectibleHashAmount;

    event FeeUpdated(uint256 previousFee, uint256 newFee);
    event PayeeUpdated(address previousPayee, address newPayee);

    event CollectibleAdded(bytes32 collectibleHash, bytes32 indexed category, address indexed seller, address indexed collection, uint256 tokenId, uint256 amount, address currency, uint256 price);
    event CollectibleRemoved(bytes32 collectibleHash, address indexed collection, uint256 tokenId, uint256 amount);

    event Purchased(bytes32 collectibleHash, address indexed purchaser, address indexed collection, uint256 tokenId, uint256 amount);
    event PurchaseCompleted(bytes32 collectibleHash, address indexed purchaser, address indexed collection, uint256 tokenId, uint256 amount); // 修正拼写错误

    constructor(address payable payee_) {
        require(payee_ != address(0), "Payee cannot be zero address");
        payee = payee_;
    }

    receive() external payable {}

    function setFee(uint256 newFee) external onlyOwner {
        require(newFee < FEE_DENOMINATOR, "Invalid value");
        uint256 previousFee = fee;
        fee = newFee;
        emit FeeUpdated(previousFee, newFee);
    }

    function setPayee(address payable newPayee) external onlyOwner {
        address previousPayee = payee;
        payee = newPayee;
        emit PayeeUpdated(previousPayee, newPayee);
    }

    function addCollectible(bytes32 category, address collection, uint256 tokenId, uint256 amount, address currency, uint256 price) external nonReentrant {
        require(category.length > 0, "Category can not be empty");
        require(IERC165(collection).supportsInterface(INTERFACE_ID_ERC721) || IERC165(collection).supportsInterface(INTERFACE_ID_ERC1155), "Not ERC721/ERC1155");

        if (IERC165(collection).supportsInterface(INTERFACE_ID_ERC721)) {
            amount = 1;
        }

        bytes32 collectibleHash = keccak256(abi.encodePacked(_msgSender(), collection, tokenId, block.number));

        Collectible storage collectible = collectibles[collectibleHash];
        collectible.category = category;
        collectible.seller = _msgSender();
        collectible.collection = collection;
        collectible.tokenId = tokenId;
        collectible.amount = amount;
        collectible.currency = currency;
        collectible.price = price;

        collectibleHashAmount[collectibleHash] = amount;

        _executeCollectibleTransferFrom(collection, _msgSender(), address(this), tokenId, amount);

        emit CollectibleAdded(collectibleHash, category, _msgSender(), collection, tokenId, amount, currency, price);
    }

    function removeCollectible(bytes32 collectibleHash) external nonReentrant {
        Collectible memory collectible = collectibles[collectibleHash];
        require(collectible.seller == _msgSender(), "Caller must be the seller of this collectible");

        delete collectibles[collectibleHash];

        _executeCollectibleTransferFrom(collectible.collection, address(this), _msgSender(), collectible.tokenId, collectible.amount);

        emit CollectibleRemoved(collectibleHash, collectible.collection, collectible.tokenId, collectible.amount);
    }

    function purchase(bytes32 collectibleHash, uint256 amount) external payable nonReentrant {
        Collectible storage collectible = collectibles[collectibleHash];
        require(collectible.seller != address(0), "Invalid collectible");
        require(amount <= collectible.amount, "Insufficient supply");

        collectible.amount -= amount;

        uint256 paymentAmount = amount * collectible.price;
        if (collectible.currency == address(0)) {
            require(msg.value >= paymentAmount, "Insufficient payment");
        } else {
            IERC20(collectible.currency).safeTransferFrom(_msgSender(), address(this), paymentAmount);
        }

        uint256 feeAmount = paymentAmount * fee / FEE_DENOMINATOR;
        _executeFundsTransfer(collectible.currency, payee, feeAmount);

        if (IERC165(collectible.collection).supportsInterface(INTERFACE_ID_ERC2981)) {
            (address receiver, uint256 royalty) = IERC2981(collectible.collection).royaltyInfo(collectible.tokenId, paymentAmount);
            feeAmount += royalty;
            if (receiver != address(0)) {
                _executeFundsTransfer(collectible.currency, receiver, royalty);
            }
        }

        _executeFundsTransfer(collectible.currency, collectible.seller, paymentAmount - feeAmount);

        _executeCollectibleTransferFrom(collectible.collection, address(this), _msgSender(), collectible.tokenId, amount);

        emit Purchased(collectibleHash, _msgSender(), collectible.collection, collectible.tokenId, amount);        

        if (collectible.amount == 0) {
            delete collectibles[collectibleHash];
            emit PurchaseCompleted(collectibleHash, _msgSender(), collectible.collection, collectible.tokenId, collectibleHashAmount[collectibleHash]);
        }
    }

    function _executeCollectibleTransferFrom(address collection, address from, address to, uint256 tokenId, uint256 amount) private {
        if (IERC165(collection).supportsInterface(INTERFACE_ID_ERC721)) {
            IERC721(collection).safeTransferFrom(from, to, tokenId, "");
        } else {
            IERC1155(collection).safeTransferFrom(from, to, tokenId, amount, "");
        }
    }

    // 初始化addresssopo
    function _executeFundsTransfer(address currency, address to, uint256 amount) private {
        if (currency == address(0)) {
            payable(to).sendValue(amount); // 使用 Address.sendValue
        } else {
            IERC20(currency).safeTransfer(to, amount);
        }
    }
}
