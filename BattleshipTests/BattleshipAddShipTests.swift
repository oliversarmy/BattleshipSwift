import UIKit
import XCTest

class BattleshipAddShipTests: XCTestCase {
    
    let playerId1 = Battle.PlayerId.Player1
    let playerId2 = Battle.PlayerId.Player2
    var b: Battle!

    override func setUp() {
        super.setUp()
        b = Battle(yDim: 5, xDim: 5)
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    func testCanAddShip() {
        var bp = b.addShip(Battle.Ship.Cruiser, playerId: Battle.PlayerId.Player1, y: 0, x: 0)
        XCTAssertTrue(bp.message == Battle.Message.ShipPlaced, "new ship created")
    }

    func testCanAdd() {
        var bp = b.addShip(Battle.Ship.Carrier, playerId: Battle.PlayerId.Player1, y: 0, x: 0)
        XCTAssertTrue(bp.message == Battle.Message.ShipPlaced, "can add if there is space")
    }

    func testPartiallyOnScreen() {
        var bp = b.addShip(Battle.Ship.Carrier, playerId: Battle.PlayerId.Player1, y: 1, x: 0, isVertical: true)
        XCTAssertTrue(bp.message == Battle.Message.ShipNotAllowedHere, "cant add the ship where it would be only partially on screen message:\(bp.message)")
    }

    func testOutOfBounds() {
        var bp = b.addShip(Battle.Ship.Patrol, playerId: Battle.PlayerId.Player1, y: -10, x: -20)
        XCTAssertTrue(bp.message == Battle.Message.ShipNotAllowedHere, "cant add the ship out of bounds")
    }

    func testOnTopOfAnotherShip() {
        var bp = b.addShip(Battle.Ship.Cruiser, playerId: Battle.PlayerId.Player1, y: 0, x: 0)
        bp = bp.battle.addShip(Battle.Ship.Patrol, playerId: Battle.PlayerId.Player1, y: 0, x: 1)
        XCTAssertTrue(bp.message == Battle.Message.ShipNotAllowedHere, "cant add the ship on top of another ship")
    }

    func testShipAlreadyPlaced() {
        var bp = b.addShip(Battle.Ship.Carrier, playerId: Battle.PlayerId.Player1, y: 0, x: 0)
        bp = bp.battle.addShip(Battle.Ship.Carrier, playerId: Battle.PlayerId.Player1, y: 1, x: 0)
        XCTAssertTrue(bp.message == Battle.Message.ShipAlreadyPlaced, "cannot place a ship twice")
    }
    
    func testRandomBoard() {
        let b = Battle()
        var battleOperation = b.randomBoardForPlayerId(playerId1)
        battleOperation = battleOperation.battle.randomBoardForPlayerId(playerId2)
        XCTAssertTrue(battleOperation.battle.battleState == Battle.BattleState.SetupComplete, "random board with all ships")
        battleOperation.battle.printBattle()
    }
    
}