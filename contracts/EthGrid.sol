pragma solidity ^0.4.23;

import "./Geometry.sol";
import "../node_modules/openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";


/// @title EthGrid
/// @author Space Dust LLC (https://spacedust.io)
/// @notice This contract represents ownership of virtual "plots" of a grid. Owners of a plot are able to brand their plots with
/// image data and a website. They are also able to put their plots up for sale and receive proceeds based on what portion of their
/// plot has been sold. A visual representation of the contract can be found by going to https://ethplot.com
/// @dev Due to storage limitations, the way the ownership data is stored for a contract is rather unique. We store an array of plot
/// ownerships which are a rectangle, an owner address, and an array pointing to elements later in the ownership array which overlap
/// with this rectangle (called holes). The remaining section of a plot, would be its original area minus the holes (rectangles on top).
/// This data model allows us to cheaply validate new purchases without building huge arrays, allocating lots of memory, or doing other
/// things which are very expensive due to gas cost concerns.
contract EthGrid is Ownable {

    /// @dev Represents a single plot (rectangle) which is owned by someone. Additionally, it contains an array
    /// of holes which point to other ZoneOwnership structs which overlap this one (and purchased a chunk of this one)
    struct ZoneOwnership {

        // Coordinates of the plot rectangle
        uint24 x;
        uint24 y;
        uint24 w;
        uint24 h;

        // The owner of the zone
        address owner;

        // The holes purchased from this ownership
        // uint256[] holes;
    }



    /// @dev Represents the data which a specific zone ownership has
    struct ZoneData {
        string ipfsHash;
        string url;
    }

    //----------------------State---------------------//
    ZoneOwnership[] public ownership;

    mapping(uint256 => ZoneData) public data;
    
    // Maps zone ID to auction price. If price is 0, no auction is 
    // available for that zone. Price is Wei per pixel.
    mapping(uint256 => uint256) public tokenIdToAuction;

    mapping(uint256 => uint256[]) public holes;
    // address[] public plotOwners;
    
    //----------------------Constants---------------------//
    uint24 constant private GRID_WIDTH = 250;
    uint24 constant private GRID_HEIGHT = 250;
    uint256 constant private INITIAL_AUCTION_PRICE = 20000 * 1000000000; // 20000 gwei (approx. $0.01)
    uint256 constant private FEE_IN_THOUSANDS_OF_PERCENT = 1000; // Initial fee is 1%

    // This is the maximum area of a single purchase block. This needs to be limited for the
    // algorithm which figures out payment to function
    uint256 constant private MAXIMUM_PURCHASE_AREA = 1000;
      
    //----------------------Events---------------------//
    event AuctionUpdated(uint256 tokenId, uint256 newPriceInWeiPerPixel, address indexed owner);
    event PlotPurchased(uint256 newZoneId, uint256 totalPrice, address indexed buyer);
    event PlotSectionSold(uint256 zoneId, uint256 totalPrice, address indexed buyer, address indexed seller);

    constructor() public payable {
        // Initialize the contract with a single block which the admin owns
        ownership.push(ZoneOwnership(0, 0, GRID_WIDTH, GRID_HEIGHT, owner));
        // plotOwners.push(owner);
        holes[0] = new uint256[](0);
        data[0] = ZoneData("Qmb51AikiN8p6JsEcCZgrV4d7C6d6uZnCmfmaT15VooUyv/img.svg", "https://www.ethplot.com/");
        tokenIdToAuction[0] = INITIAL_AUCTION_PRICE;
        // setAuctionPrice(0, INITIAL_AUCTION_PRICE);
    }


    //----------------------External Functions---------------------//
    function purchaseAreaWithData(
        uint24[] purchase,
        uint256[] purchasedAreas,
        uint256[] areaIndices,
        string ipfsHash,
        string url,
        uint256 initialBuyoutPriceInWeiPerPixel) external payable {
        
        uint256 initialPurchasePrice = validatePurchases(purchase, purchasedAreas, areaIndices);

        // plotOwners.push(msg.sender);
        holes[ownership.length] = new uint256[](0);

        // Now that purchase is completed, update zones that have new holes due to this purchase
        uint256 i = 0;
        for (i = 0; i < areaIndices.length; i++) {
            holes[areaIndices[i]].push(ownership.length);
        }

        // Take in the input data for the actual grid!
        data[ownership.length] = ZoneData(ipfsHash, url);

        // Set an initial purchase price for the new plot as specified and emit a purchased event
        tokenIdToAuction[ownership.length] = initialBuyoutPriceInWeiPerPixel;

        // setAuctionPrice(ownership.length - 1, initialBuyoutPriceInWeiPerPixel);
        emit PlotPurchased(ownership.length, initialPurchasePrice, msg.sender);

        // Add the new ownership to the array
        ZoneOwnership memory newZone = ZoneOwnership({
            x: purchase[0],
            y: purchase[1],
            w: purchase[2],
            h: purchase[3],
            owner: msg.sender
        });
        ownership.push(newZone);

    }

    // Can also be used to cancel an existing auction by sending 0 (or less) as new price.
    function updateAuction(uint256 zoneIndex, uint256 newPriceInWeiPerPixel) public {
        setAuctionPrice(zoneIndex, newPriceInWeiPerPixel);
        emit AuctionUpdated(zoneIndex, newPriceInWeiPerPixel, msg.sender);
    }

    function setAuctionPrice(uint256 zoneIndex, uint256 newPriceInWeiPerPixel) private {
        require(zoneIndex >= 0);
        require(zoneIndex < ownership.length);
        require(msg.sender == ownership[zoneIndex].owner);

        tokenIdToAuction[zoneIndex] = newPriceInWeiPerPixel;
    }
    
    function withdraw(address transferTo) onlyOwner external {
        // Prevent https://consensys.github.io/smart-contract-best-practices/known_attacks/#transaction-ordering-dependence-tod-front-running
        require(transferTo == owner);

        uint256 currentBalance = address(this).balance;
        owner.transfer(currentBalance);
    }

    //----------------------Public View Functions---------------------//
    // function getPlot(uint256 zoneIndex) public view returns (uint16, uint16, uint16, uint16, address, uint256, string, string) {
    //     require(zoneIndex < ownership.length);

    //     // uint256 price = tokenIdToAuction[zoneIndex];
    //     // ZoneData memory zoneData = data[zoneIndex];

    //     return (
    //         ownership[zoneIndex].x,
    //         ownership[zoneIndex].y,
    //         ownership[zoneIndex].w,
    //         ownership[zoneIndex].h,
    //         plotOwners[zoneIndex],
    //         tokenIdToAuction[zoneIndex],
    //         data[zoneIndex].url,
    //         data[zoneIndex].ipfsHash);
    // }

    function ownershipLength() public view returns (uint256) {
        return ownership.length;
    }
    
    //----------------------Private Functions---------------------//
    function distributePurchaseFunds(
        Geometry.Rect memory rectToPurchase, Geometry.Rect[] memory rects, uint256[] memory areaIndices) private returns (uint256) {
        uint256 remainingBalance = msg.value;

        uint256 owedToSeller = 0;
        for (uint256 areaIndicesIndex = 0; areaIndicesIndex < areaIndices.length; areaIndicesIndex++) {
            uint256 ownershipIndex = areaIndices[areaIndicesIndex];

            Geometry.Rect memory currentOwnershipRect = Geometry.Rect(
                ownership[ownershipIndex].x, ownership[ownershipIndex].y, ownership[ownershipIndex].w, ownership[ownershipIndex].h);

            // This is a zone the caller has declared they were going to buy
            // We need to verify that the rectangle which was declared as what we're gonna buy is completely contained within the overlap
            require(Geometry.doRectanglesOverlap(rectToPurchase, currentOwnershipRect));
            Geometry.Rect memory overlap = Geometry.computeRectOverlap(rectToPurchase, currentOwnershipRect);

            // Verify that this overlap between these two is within the overlapped area of the rect to purchase and this ownership zone
            require(rects[areaIndicesIndex].x >= overlap.x);
            require(rects[areaIndicesIndex].y >= overlap.y);
            require(rects[areaIndicesIndex].x + rects[areaIndicesIndex].w <= overlap.x + overlap.w);
            require(rects[areaIndicesIndex].y + rects[areaIndicesIndex].h <= overlap.y + overlap.h);

            // Next, verify that none of the holes of this zone ownership overlap with what we are trying to purchase
            for (uint256 holeIndex = 0; holeIndex < holes[ownershipIndex].length; holeIndex++) {
                ZoneOwnership memory holeOwnership = ownership[holes[ownershipIndex][holeIndex]];
                Geometry.Rect memory holeRect = Geometry.Rect(
                    holeOwnership.x,
                    holeOwnership.y,
                    holeOwnership.w,
                    holeOwnership.h);

                require(!Geometry.doRectanglesOverlap(rects[areaIndicesIndex], holeRect));
            }


            // Finally, add the price of this rect to the totalPrice computation
            uint256 sectionPrice = getPriceOfAuctionedZone(rects[areaIndicesIndex], ownershipIndex);
            remainingBalance = SafeMath.sub(remainingBalance, sectionPrice);
            owedToSeller = SafeMath.add(owedToSeller, sectionPrice);

            // If this is the last one to look at, or if the next ownership index is different, payout this owner
            if (areaIndicesIndex == areaIndices.length - 1 || ownershipIndex != areaIndices[areaIndicesIndex + 1]) {
                // Update the balances and emit an event to indicate the chunks of this plot which were sold
                address(ownership[ownershipIndex].owner).transfer(owedToSeller);
                emit PlotSectionSold(ownershipIndex, owedToSeller, msg.sender, ownership[ownershipIndex].owner);
                owedToSeller = 0;
            }
        }
        
        
        // uint256 areaIndicesIndex = 0;

        // // Walk the ownership array backwards. Do funny checks for incrementing and decrementing indices becaues uints will wrap
        // for (uint256 ownershipIndex = ownership.length - 1;
        //      areaIndicesIndex < areaIndices.length && ownershipIndex < ownership.length;
        //      ownershipIndex--) {

        //     uint256 owedToSeller = 0;

        //     // Keep looping through while we are declaring that we want this area
        //     while (areaIndicesIndex < areaIndices.length && ownershipIndex == areaIndices[areaIndicesIndex]) {
        //         Geometry.Rect memory currentOwnershipRect = Geometry.Rect(
        //             ownership[ownershipIndex].x, ownership[ownershipIndex].y, ownership[ownershipIndex].w, ownership[ownershipIndex].h);

        //         // This is a zone the caller has declared they were going to buy
        //         // We need to verify that the rectangle which was declared as what we're gonna buy is completely contained within the overlap
        //         require(Geometry.doRectanglesOverlap(rectToPurchase, currentOwnershipRect));
        //         Geometry.Rect memory overlap = Geometry.computeRectOverlap(rectToPurchase, currentOwnershipRect);

        //         // Verify that this overlap between these two is within the overlapped area of the rect to purchase and this ownership zone
        //         require(rects[areaIndicesIndex].x >= overlap.x);
        //         require(rects[areaIndicesIndex].y >= overlap.y);
        //         require(rects[areaIndicesIndex].x + rects[areaIndicesIndex].w <= overlap.x + overlap.w);
        //         require(rects[areaIndicesIndex].y + rects[areaIndicesIndex].h <= overlap.y + overlap.h);

        //         // Next, verify that none of the holes of this zone ownership overlap with what we are trying to purchase
        //         for (uint256 holeIndex = 0; holeIndex < holes[ownershipIndex].length; holeIndex++) {
        //             ZoneOwnership memory holeOwnership = ownership[holes[ownershipIndex][holeIndex]];
        //             Geometry.Rect memory holeRect = Geometry.Rect(
        //                 holeOwnership.x,
        //                 holeOwnership.y,
        //                 holeOwnership.w,
        //                 holeOwnership.h);

        //             require(!Geometry.doRectanglesOverlap(rects[areaIndicesIndex], holeRect));
        //         }


        //         // Finally, add the price of this rect to the totalPrice computation
        //         uint256 sectionPrice = getPriceOfAuctionedZone(rects[areaIndicesIndex], areaIndices[areaIndicesIndex]);
        //         remainingBalance = SafeMath.sub(remainingBalance, sectionPrice);
        //         owedToSeller = SafeMath.add(owedToSeller, sectionPrice);

        //         areaIndicesIndex++;
        //     }

        //     if (owedToSeller > 0) {
        //         // Update the balances and emit an event to indicate the chunks of this plot which were sold
        //         address(ownership[ownershipIndex].owner).transfer(owedToSeller);
        //         emit PlotSectionSold(ownershipIndex, owedToSeller, msg.sender, ownership[ownershipIndex].owner);
        //     }
        // }

        // // This means we checked every area index
        // require(areaIndicesIndex == areaIndices.length);

        return remainingBalance;
    }

    function validatePurchases(uint24[] purchase, uint256[] purchasedAreas, uint256[] areaIndices) private returns (uint256) {
        require(purchase.length == 4);
        Geometry.Rect memory rectToPurchase = Geometry.Rect(purchase[0], purchase[1], purchase[2], purchase[3]);
        
        // TODO - Safe Math
        require(rectToPurchase.x < GRID_WIDTH && rectToPurchase.x >= 0);
        require(rectToPurchase.y < GRID_HEIGHT && rectToPurchase.y >= 0);
        require(rectToPurchase.w > 0 && rectToPurchase.w + rectToPurchase.x <= GRID_WIDTH);
        require(rectToPurchase.h > 0 && rectToPurchase.h + rectToPurchase.y <= GRID_HEIGHT);
        require(rectToPurchase.w * rectToPurchase.h < MAXIMUM_PURCHASE_AREA);

        require(purchasedAreas.length >= 4);
        require(areaIndices.length > 0);
        require(purchasedAreas.length % 4 == 0);
        require(purchasedAreas.length / 4 == areaIndices.length);

        Geometry.Rect[] memory rects = new Geometry.Rect[](areaIndices.length);

        uint256 totalArea = 0;
        uint256 i = 0;
        uint256 j = 0;
        for (i = 0; i < areaIndices.length; i++) {
            // Define the rectangle and add it to our collection of them
            Geometry.Rect memory rect = Geometry.Rect(
                purchasedAreas[(i * 4)], purchasedAreas[(i * 4) + 1], purchasedAreas[(i * 4) + 2], purchasedAreas[(i * 4) + 3]);
            rects[i] = rect;

            // Compute the area of this rect and add it to the total area
            totalArea = SafeMath.add(totalArea, SafeMath.mul(rect.w,rect.h));

            // Verify that this rectangle is within the bounds of the area we are trying to purchase
            require(rect.x >= rectToPurchase.x);
            require(rect.y >= rectToPurchase.y);
            require(rect.x + rect.w <= rectToPurchase.x + rectToPurchase.w);
            require(rect.y + rect.h <= rectToPurchase.y + rectToPurchase.h);
        }

        require(totalArea == rectToPurchase.w * rectToPurchase.h);

        // Next, make sure all of these do not overlap
        for (i = 0; i < rects.length; i++) {
            for (j = i + 1; j < rects.length; j++) {
                require(!Geometry.doRectanglesOverlap(rects[i], rects[j]));
            }
        }

        // If we have a matching area, the sub rects are all contained within what we're purchasing, and none of them overlap,
        // we know we have a complete tiling of the rectToPurchase. Next, compute what the price should be for all this
        uint256 remainingBalance = distributePurchaseFunds(rectToPurchase, rects, areaIndices);
        uint256 purchasePrice = SafeMath.sub(msg.value, remainingBalance);

        // The remainingBalance after distributing funds to sellers should greater than or equal to the fee we charge
        uint256 requiredFee = SafeMath.div(SafeMath.mul(purchasePrice, FEE_IN_THOUSANDS_OF_PERCENT), (1000 * 100));
        require(remainingBalance >= requiredFee);
        
        return purchasePrice;
    }

    // Given a rect to purchase, and the ID of the zone that is part of the purchase,
    // This returns the total price of the purchase that is attributed by that zone.  
    function getPriceOfAuctionedZone(Geometry.Rect memory rectToPurchase, uint256 auctionedZoneId) private view returns (uint256) {
        // Check that this auction zone exists in the auction mapping with a price.
        uint256 auctionPricePerPixel = tokenIdToAuction[auctionedZoneId];
        require(auctionPricePerPixel > 0);

        return SafeMath.mul(SafeMath.mul(rectToPurchase.w, rectToPurchase.h), auctionPricePerPixel);
    }
}