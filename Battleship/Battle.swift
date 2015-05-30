import Foundation

// This class represets a point in time of a battle. 
// Its immutable. To progress, a new Battle is created.
// There are two players each with a 2D board, on which ships can be placed and fired at.
class Battle {

    typealias BoardType = [[SeaScape]] // 2D board with ships, water and misses on it (Hits are on Ships!)
    
    // all the various items you can have on the sea
    enum SeaScape: Printable {
        case Water, Miss
        case ShipSectionNominal(Ship)
        case ShipSectionDamaged(Ship)
        case ShipSectionSunk(Ship)
        var description: String {
            switch self {
            case .Water: return "_"
            case .Miss: return "~"
            case let .ShipSectionNominal(s): return s.description
            case .ShipSectionDamaged(_): return "X"
            case let .ShipSectionSunk(s): return s.description.lowercaseString
            }
        }
        var isNominal: Bool { // the ship section is undamaged
            switch self {
            case .ShipSectionNominal(_): return true
            default: return false
            }
        }
        var isShip: Bool {
            switch self {
            case .ShipSectionNominal(_), .ShipSectionDamaged(_), .ShipSectionSunk(_): return true
            default: return false
            }
        }
    }

    // types of ship that can go on the sea
    enum Ship: String, Printable  {
        case Carrier = "A", Battleship = "B", Submarine = "S", Cruiser = "C", Patrol = "P"
        var description : String {
            return self.rawValue
        }
        var shipLength: Int {
            switch self {
            case .Carrier: return 5
            case .Battleship: return 4
            case .Submarine: return 3
            case .Cruiser: return 2
            case .Patrol: return 1
            }
        }
        static var allShips: [Ship] {
            return [Battle.Ship.Carrier, Battle.Ship.Battleship, Battle.Ship.Submarine, Battle.Ship.Cruiser, Battle.Ship.Patrol]
        }
        static var nrOfShips: Int {
            return allShips.count
        }
    }

    // battleState to go in one direction only ->
    enum BattleState: String, Printable  {
        case Setup = "Setup", SetupComplete = "SetupComplete", Playing = "Playing", GameOver = "GameOver"
        var description : String {
            return self.rawValue
        }
    }
    
    // messages to allow api users to get a little information about what went right or wrong
    enum Message: String, Printable {
        case Hit = "Hit", Miss = "Miss"
        case HitSameSpot = "HitSameSpot", MissSameSpot = "MissSameSpot", ShotOutOfBounds = "ShotOutOfBounds"
        case ShipNotAllowedHere = "ShipNotAllowedHere", ShipAlreadyPlaced = "ShipAlreadyPlaced"
        case ShipPlaced = "ShipPlaced", AllShipsPlaced = "AllShipsPlaced"
        case GameStarted = "gameHasStarted", GameNotInPlay = "GameNotInPlay", NotThisPlayersTurn = "NotThisPlayersTurn"
        var description : String {
            return self.rawValue
        }
    }
    
    // communicate the result of an operation on the battle, along with an updated battle object
    struct BattleOperation {
        let message: Message
        let battle: Battle
        let justSunk: Ship?
        
        init(message: Message, battle: Battle, justSunk: Ship? = .None) {
            self.message = message
            self.battle = battle
            self.justSunk = justSunk
        }
    }
    
    // alowed players
    enum PlayerId: String, Printable {
        case Player1 = "Player1", Player2 = "Player2"
        var description : String {
            return self.rawValue
        }
    }
    
    // these are the three obects that will change, each time a new battle object is generated
    private let battleStore: BattleStore
    private let idShotLast: PlayerId?
    let battleState: BattleState
    
    // next point of a battle
    private init(battleStore: BattleStore, battleState: BattleState, idShotLast: PlayerId?) {
        self.battleStore = battleStore
        self.idShotLast = idShotLast
        self.battleState = battleState
    }
    
    // yup you can create a different sized board, but 10 * 10 is good
    convenience init(yDim: Int = 10, xDim: Int = 10) {
        self.init(battleStore: BattleStore(yDim: yDim, xDim: xDim), battleState: BattleState.Setup, idShotLast: .None)
    }

    // battle state is changing, so create a new battle for this point in time
    private func newBattle(playerId: PlayerId, board: BoardType, firedOnByPlayerId: PlayerId? = .None, didLose: Bool = false) -> Battle {
        
        var newBattleStore = battleStore // this makes the "new" structure mutable
        newBattleStore.setBoard(board, forPlayerId: playerId) // update the board
        
        let newBattleState: BattleState
        switch battleState {
        case .Setup where newBattleStore.setupComplete(): newBattleState = .SetupComplete
        case .SetupComplete where firedOnByPlayerId != nil: newBattleState = .Playing
        case .Playing where didLose: newBattleState = .GameOver
        default: newBattleState = battleState
        }
        
        return Battle(battleStore: newBattleStore, battleState: newBattleState, idShotLast: firedOnByPlayerId ?? idShotLast)
    }

    // add a ship, but only for the setup stage and only if its not already added, is not on another ship or off the board
    func addShip(ship: Ship, playerId: PlayerId, y: Int, x: Int, isVertical: Bool = false) -> BattleOperation {
        
        let board = battleStore.boardForPlayerId(playerId)
        switch battleStore.stateForPlayerId(playerId) {
        case .BoardSetupComplete: return BattleOperation(message:.AllShipsPlaced, battle: self)
        case .BoardSetup where BattleStore.isShip(ship, onBoard: board): return BattleOperation(message:.ShipAlreadyPlaced, battle: self)
        default: ()
        }
        
        if let pairs = BattleStore.pairsOverWaterForBoard(board, isVertical: isVertical, y: y, x: x, len: ship.shipLength) {
            var vBoard = board
            for (y, x) in pairs {
                vBoard[y][x] = SeaScape.ShipSectionNominal(ship)
            }
        
            return BattleOperation(message:.ShipPlaced, battle: newBattle(playerId, board: vBoard))
        } else {
            return BattleOperation(message:.ShipNotAllowedHere, battle: self)
        }
    }
    
    // after all Ships are placed, the first shot will start the game
    // when the opponent has no Ships left on the board, the game will complete
    func shootAtPlayerId(playerId: PlayerId, y: Int, x: Int) -> BattleOperation {
        
        let firingPlayerId = playerId == PlayerId.Player1 ? PlayerId.Player2 : PlayerId.Player1
        switch battleState {
        case .Playing, .SetupComplete:
            switch idShotLast {
            case .Some(firingPlayerId): return BattleOperation(message:.NotThisPlayersTurn, battle: self)
            default: ()
            }
        default: return BattleOperation(message:.GameNotInPlay, battle: self)
        }
        
        var vBoard = battleStore.boardForPlayerId(playerId)
        var vDidLose = false
        var vJustSunk: Ship? = .None
        let message: Message
        switch vBoard[y][x] {
        case let .ShipSectionNominal(ship):
            message = .Hit
            vBoard[y][x] = .ShipSectionDamaged(ship)
            if !BattleStore.isNominalShip(ship, onBoard: vBoard) { // check if its sunk
                vBoard = BattleStore.sinkShip(ship, onBoard: vBoard)
                vDidLose = BattleStore.nrOfNominalShipsOnBoard(vBoard) == 0
                vJustSunk = ship
            }
        case .ShipSectionDamaged(_), .ShipSectionSunk(_):
            message = .HitSameSpot
        case .Water:
            message = .Miss
            vBoard[y][x] = .Miss
        case .Miss:
            message = .MissSameSpot
        }
        
        return BattleOperation(message: message,
                                battle: newBattle(playerId, board: vBoard, firedOnByPlayerId: firingPlayerId, didLose: vDidLose),
                              justSunk: vJustSunk)
    }
    
    // randomly set the ships, has the potential to fail, if the board is too small to fit all the ships
    func randomBoardForPlayerId(playerId: PlayerId, ships: [Battle.Ship] = Battle.Ship.allShips) -> BattleOperation {
        
        if ships.count == 0 {
            return BattleOperation(message: Battle.Message.AllShipsPlaced, battle: self)
        }
        let board = battleStore.boardForPlayerId(playerId)
        let ship = ships[0]
        let restOfShips = Array(dropFirst(ships))
        
        let potentialPositions = BattleStore.pairsForBoard(board) // all y,x pairs for the board
        let pairs: [(y: Int, x: Int)]
        let isVertical: Bool = arc4random() % 2 == 0
        pairs = potentialPositions.filter {BattleStore.pairsOverWaterForBoard(board, isVertical: isVertical, y: $0.y, x: $0.x, len: ship.shipLength) != nil}
  
        let randomPairs = sorted(pairs) {_, _ in arc4random() % 2 == 0}
        for pair in randomPairs {
            let battleOperation = addShip(ship, playerId: playerId, y: pair.y, x: pair.x, isVertical: isVertical)
            if (battleOperation.message == Battle.Message.ShipNotAllowedHere) {
                NSLog("all the pairs should be ok: pair generation error")
            }
            switch battleOperation.battle.randomBoardForPlayerId(playerId, ships: restOfShips) {
            case let battleOperation where battleOperation.message == Battle.Message.AllShipsPlaced: return battleOperation
            default: ()
            }
        }
        return BattleOperation(message: Battle.Message.ShipNotAllowedHere, battle: self)
    }
    
    // accessor to a board for api
    func boardForPlayerId(playerId: PlayerId) -> BoardType {
        return battleStore.boardForPlayerId(playerId)
    }
    
    // just in case they want to know
    func whoWon() -> PlayerId? {
        switch battleState {
        case .GameOver: return idShotLast
        default: return nil
        }
    }
    
    // store for player's boards and operations on boards
    private struct BattleStore {
        enum BoardState  {  // represents state of a individual board
            case BoardSetup, BoardSetupComplete
        }
        
        private var board1: BoardType // player1 boards (was going to use a dictionary, but swift 1.2 beta and dictionaries are currently buggy)
        private var board2: BoardType
        
        init(yDim: Int = 10, xDim: Int = 10) {
            let emptyRow = [SeaScape](count: xDim, repeatedValue: SeaScape.Water)
            board1 = BoardType(count: yDim, repeatedValue: emptyRow) // setting up multi dimentional arrays
            board2 = board1
        }
        
        // update the board for one player. It's a value object, so this isn't going to trample on anyone
        mutating func setBoard(board: BoardType, forPlayerId: PlayerId) {
            switch forPlayerId {
            case .Player1: board1 = board
            case .Player2: board2 = board
            }
        }
        
        func boardForPlayerId(playerId: PlayerId) -> BoardType {
            return playerId == PlayerId.Player1 ? board1 : board2
        }
        
        // have all the ships been placed for all players
        func setupComplete() -> Bool {
            return stateForPlayerId(PlayerId.Player1) == .BoardSetupComplete &&  stateForPlayerId(PlayerId.Player2) == .BoardSetupComplete
        }
        
        // has all the ships been placed for this player
        func stateForPlayerId(playerId: PlayerId) -> BoardState {
            return BattleStore.nrOfShipsOnBoard(boardForPlayerId(playerId)) == Ship.nrOfShips ? BoardState.BoardSetupComplete : .BoardSetup
        }
        
        // helper functions. These are static to help indicate they are just pure functions
        
        static func isNominalShip(ship: Ship, onBoard: BoardType) -> Bool {
            // using description as contains doesnt want to play with enums, easily
            // swift has no flatmap, so use reduce
            let shipSections = onBoard.reduce([], combine: +).filter{$0.isNominal && $0.description == ship.description}
            return shipSections.count > 0
        }
        
        static func isShip(ship: Ship, onBoard: BoardType) -> Bool {
            let shipSections = onBoard.reduce([], combine: +).filter{$0.isShip && $0.description.uppercaseString == ship.description}
            return shipSections.count > 0
        }
        
        static func nrOfShipsOnBoard(board: BoardType) -> Int {
            let shipSections = board.reduce([], combine: +).filter{$0.isShip}.map{$0.description.uppercaseString}
            return Set(shipSections).count
        }
        
        static func nrOfNominalShipsOnBoard(board: BoardType) -> Int {
            let shipSections = board.reduce([], combine: +).filter{$0.isNominal}.map{$0.description.uppercaseString}
            return Set(shipSections).count
        }
        
        static let dimYx = {(board: BoardType) -> (yDim :Int, xDim: Int) in (yDim: board.count, xDim: board.count > 0 ? board[0].count : 0)}
        
        // get all the pairs for the whole board
        static func pairsForBoard(board: BoardType) -> [(y: Int, x: Int)] {
            let dim = dimYx(board)
            return (0 ..< dim.yDim).map {y in (0 ..< dim.xDim).map{(y: y, x: $0)}}.reduce([], combine: +)
        }
        
        // get the pairs that represent a particular ship
        static func pairsForShip(ship: Ship, onBoard: BoardType) -> [(y: Int, x: Int)] {
            let pairs = BattleStore.pairsForBoard(onBoard)
            return pairs.filter {y, x in
                switch onBoard[y][x] {
                case .ShipSectionNominal(ship), .ShipSectionDamaged(ship), .ShipSectionSunk(ship): return true
                default: return false
                }
            }
        }
        
        // sink every section of a ship
        static func sinkShip(ship: Ship, onBoard: BoardType) -> BoardType {
            var vBoard = onBoard
            for pair in BattleStore.pairsForShip(ship, onBoard: onBoard) {
                vBoard[pair.y][pair.x] = .ShipSectionSunk(ship)
            }
            return vBoard
        }
        
        // checks that the generated pairs are over water
        private static func pairsOverWaterForBoard(board: BoardType, pairs: [(y:Int, x:Int)]) -> [(y:Int, x:Int)]? {
            let dim = dimYx(board)
            for (y, x) in pairs {
                if x < 0 || y < 0 || x >= dim.xDim || y >= dim.yDim {
                    return nil
                }
                switch board[y][x] {
                case .Water: continue
                default: return nil
                }
            }
            return pairs
        }
        
        // generate pairs for a ship and check all the ship is over water
        static func pairsOverWaterForBoard(board: BoardType, isVertical: Bool, y: Int, x: Int, len: Int) -> [(y:Int, x:Int)]? {
            if isVertical {
                return BattleStore.pairsOverWaterForBoard(board, pairs: (y ..< y + len).map { (y: $0, x: x) })
            } else {
                return BattleStore.pairsOverWaterForBoard(board, pairs: (x ..< x + len).map { (y: y, x: $0) })
            }
        }
        
    }
    
    // pragma mark - just for testing/debugging
    
    func printBattle() {
        println("\nBattle State \(battleState)\n")
        printBoard(PlayerId.Player1)
        println("\n")
        printBoard(PlayerId.Player2)
    }
    
    func printBoard(playerId: PlayerId) {
        let board = battleStore.boardForPlayerId(playerId)
        
        func printBoard(board: Battle.BoardType) {
            var vInc = 1
            for boardRow in board {
                println(boardRow.reduce("\(vInc++) ", combine:{"\($0) \($1)"}))
            }
        }
        
        let xDim = BattleStore.dimYx(board).xDim
        
        let header = "   " + " ".join((1 ... xDim).map{$0.description})
        println("\(header) \(playerId.description)")
        printBoard(board)
    }
    
}

// need these because the enum has an associated type

func !=(a:Battle.SeaScape, b:Battle.SeaScape) -> Bool {
    return !(==)(a, b)
}

func ==(a:Battle.SeaScape, b:Battle.SeaScape) -> Bool {
    switch(a, b) {
    case (.Water, .Water), (.Miss, .Miss): return true
    case let (s1, s2): return s1.description == s2.description
    default: return false
    }
}