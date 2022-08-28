// SPDX-License-Identifier: MIT
pragma solidity ^0.8.1;
import "@openzeppelin/contracts/access/Ownable.sol";


contract TechnoLimeMarketplace is Ownable {

    struct Item {
        uint256 id;
        string itemType;
        address payable owner;
        uint256 quantity;
        uint256 price;
        uint256 lastSaleBlock;
    }

    Item[] public itemsForSale;
    Item[] public soldItems;
    mapping(string => bool) public activeItemTypes;
    mapping(string => address[]) public pastBuyersByItemType;

    //Events
    event itemAddedForSale(
        uint256 id,
        string itemType,
        address owner,
        uint256 quantity,
        uint256 price
    );
    event itemSold(uint256 id, address buyer, uint256 quantity, uint256 price);
    event quantityAddedForAnItem(uint256 id, address owner, uint256 quantityAdded);

    //Modifier, Check if item listed for sale
    modifier ItemExists(uint256 id) {
        require(
            id < itemsForSale.length && itemsForSale[id].id == id,
            "Item not listed for sale"
        );
        require(
            activeItemTypes[itemsForSale[id].itemType],
            "Item type hasn't been created"
        );
        _;
    }

    //Check if address is first time buyer
    modifier isFirstTimeBuyer(string memory itemType) {
        bool firstTimer = true;
        for(uint i; i < pastBuyersByItemType[itemType].length; i++){
            if(pastBuyersByItemType[itemType][i] == msg.sender){
               firstTimer = false;
            }
        }
        require(firstTimer, "Address has already bought this item type before");
        _;
    }

    /* ======== FUNCTIONS ======== */

    /*
     *@notice List item for sale
     *@param itemType string, item type
     *@param price(in wei) uint256, item selling price
     *@return uint(newItemId)
     */
    function putItemForSale(uint256 price, string memory itemType, uint256 quantity)
        external
        onlyOwner
        returns (uint256)
    {
        require(!activeItemTypes[itemType], "Item type is already up for sale");
        require(price > 0, "Price should be greater than 0");
        require(quantity > 0, "Quantity should be greater than 0");

        uint256 newItemId = itemsForSale.length;
        itemsForSale.push(
            Item({
                itemType: itemType,
                id: newItemId,
                owner: payable(msg.sender),
                quantity: quantity,
                price: price,
                lastSaleBlock: 0
            })
        );
        activeItemTypes[itemType] = true;
        assert(itemsForSale[newItemId].id == newItemId);
        emit itemAddedForSale(newItemId, itemType, msg.sender, quantity, price);
        return newItemId;
    }
    /*
     *@notice Add more quantity to a certain item type
     *@param string itemType, how much to add
     *@param uint256 quantityToAdd, how much to add
     *@return uint(id)
     */
    function addQuantityToAnItem(uint256 id, uint256 quantityToAdd)
        external
        ItemExists(id)
        onlyOwner
        returns (uint256)
    {
        require(quantityToAdd > 0, "Have to add atleast 1");
        itemsForSale[id].quantity += quantityToAdd;

        emit quantityAddedForAnItem(itemsForSale[id].id, msg.sender, quantityToAdd);
        return itemsForSale[id].id;
    }
    /*
     *  @notice Buy an item
     *  @param uint256 id, index of item
     *  @param uint256 quantity, how much of the item you want to buy
     *  @param string itemType, what type of item you want to buy
     */
    function buyItem(uint256 id, uint256 quantity, string memory itemType)
        external
        payable
        ItemExists(id)
        isFirstTimeBuyer(itemType)
    {
        require(quantity > 0, "Have to buy atleast 1");
        require(msg.value >= itemsForSale[id].price * quantity, "Not enough funds sent");
        require(quantity <= itemsForSale[id].quantity, "Not enough of the item is available");
        require(msg.sender != itemsForSale[id].owner);
        uint256 boughtItemId = soldItems.length;
        itemsForSale[id].quantity -= quantity;
        soldItems.push(
            Item({
                itemType: itemsForSale[id].itemType,
                id: boughtItemId,
                owner: payable(msg.sender),
                quantity: quantity,
                price: itemsForSale[id].price,
                lastSaleBlock: block.number
            })
        );
        //remember that this address is now in possesion of this type of item
        pastBuyersByItemType[itemType].push(msg.sender);
        emit itemSold(
            id,
            msg.sender,
            quantity,
            itemsForSale[id].price
        );
    }
    /*
     *  @notice Buy more from an item of certain type
     *  @param uint256 id, index of item
     *  @param uint256 quantity, how much of the item you want to buy
     */
    function buyMoreOfItem(uint256 listedItemId, uint256 soldItemId, uint256 quantity)
        external
        payable
        ItemExists(listedItemId)
    {
        require(msg.sender == soldItems[soldItemId].owner, "You have to own the item first");
        require(quantity > 0, "Have to buy atleast 1");
        require(msg.value >= itemsForSale[listedItemId].price * quantity, "Not enough funds sent");
        require(quantity <= itemsForSale[listedItemId].quantity, "Not enough of the item is available");
        itemsForSale[listedItemId].quantity -= quantity;
        soldItems[soldItemId].quantity += quantity;
        soldItems[soldItemId].lastSaleBlock = block.number;
    }
    /*
     *  @notice request a refund and return item's quantity to admin
     *  @param uint256 id, index of item
     *  @param uint256 quantity, how much of the item you want to buy
     */
    function requestRefund(uint256 listedItemId, uint256 soldItemId, uint256 quantity)
        external
        payable
        ItemExists(listedItemId)
    {
        require(msg.sender == soldItems[soldItemId].owner, "You have to own the item first");
        require(quantity <= soldItems[soldItemId].quantity, "You don't have enough of the item");
        require(block.number <= soldItems[soldItemId].lastSaleBlock + 100, "100 blocks have passed. Can't refund");
        itemsForSale[listedItemId].quantity += quantity;
        soldItems[soldItemId].quantity -= quantity;
        payable(msg.sender).transfer(soldItems[soldItemId].price * quantity);
    }
    /*
     *  @notice Get total number of items for sale
     *  @return uint
     */
    function totalItemsForSale() external view returns (uint256) {
        return itemsForSale.length;
    }
    /*
     *  @notice Get total number of items sold
     *  @return uint
     */
    function totalItemsSold() external view returns (uint256) {
        return soldItems.length;
    }
    /*
     *  @notice Get all sold items
     *  @return tuple
     */
    function getSoldItems() external view returns (Item[] memory) {
        return soldItems;
    }
    /*
     *  @notice Get all items for sale
     *  @return tuple
     */
    function getListedItems() external view returns (Item[] memory) {
        return itemsForSale;
    }

}