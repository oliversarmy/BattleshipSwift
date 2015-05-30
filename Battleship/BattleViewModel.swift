import Foundation

// The ally and enemy controllers each register a listener and receives notification of board updates
// The ally can start a new game
// or request new ship placements, if the game hasn't started
// or fire on the enemy. The enemy immediately shoots back
class BattleViewModel {

    enum GameStatus {
    case NotStarted, Started
    }
    
    var gameStatus = GameStatus.NotStarted
    let xDim = 10 // dimensions of the board
    let yDim = 10
    private let allyPlayerId = Battle.PlayerId.Player1
    private let enemyPlayerId = Battle.PlayerId.Player2
    private var vBondAlly: BondPlayer // contains listeners, to inform controllers of changes
    private var vBondEnemy: BondPlayer
    private var vRandomIndexs: [Int] = []
    private var vEnemyBattleStart: Battle // Battle that just has the enemy ship. Ally ships not yet deployed
    private var vBattle: Battle

    init() {
        vBattle = Battle(yDim: yDim, xDim: xDim)
        vEnemyBattleStart = vBattle
        vBondAlly = BondPlayer(battle: vBattle, playerId: allyPlayerId)
        vBondEnemy = BondPlayer(battle: vBattle, playerId: enemyPlayerId)
    }
    
    // Create a brand new battle with random ships for the enemy. The players ships will be created later
    func restart() {
        gameStatus = GameStatus.NotStarted
        vEnemyBattleStart = Battle(yDim: yDim, xDim: xDim).randomBoardForPlayerId(enemyPlayerId).battle
        vBondEnemy.updateBondArray(vEnemyBattleStart)
        vBattle = vEnemyBattleStart // listeners will be informed on calling update ships
    }
    
    // Allow the UI to react to changes on the array representing their ships. 
    // An array of changed indices will be returned
    func addUpdateListener(#imThePlayer: Bool, updateListener: [Int] -> Void) {
        let player = imThePlayer ? vBondAlly : vBondEnemy
        player.listener = updateListener
    }
    
    // the enemy allready has their ships setup, just create/recreate the players
    func randomShipsForPlayer() {
        let battleOperation = vEnemyBattleStart.randomBoardForPlayerId(allyPlayerId)
        vBattle = battleOperation.battle
        vBondAlly.updateBondArray(vBattle)
    }
    
    // the string representing the current cell on the board
    func boardDescriptionForIndex(index: Int, imThePlayer: Bool) -> String {
        let player = imThePlayer ? vBondAlly : vBondEnemy
        return player.vBoard1D[index].description
    }
    
    // gets called once for each set of array changes
    func gameOverString() -> String? {
        switch vBattle.whoWon() {
        case .None: return nil
        case .Some(.Player1): return "Game Over and You Won! Play again?"
        case .Some(.Player2): return "Sorry you have been beaten! Do you want to try one more time?"
        }
    }
    
    // change the UI's one dimention representation of a board to a two dimentional one and shoot
    private func shootAtPlayerId(playerId: Battle.PlayerId, index: Int) -> Battle.BattleOperation {
        let y = index / xDim
        let x = index % xDim
        let battleOp = vBattle.shootAtPlayerId(playerId, y: y, x: x)
        println("\(playerId) \(battleOp.message)")
        return battleOp
    }
    
    // always the player that shoots first
    func shootIndex(index: Int) {
        gameStatus = .Started
        vBattle = shootAtPlayerId(enemyPlayerId, index: index).battle
        vBondEnemy.updateBondArray(vBattle)
        
        // shoot back, but not with much smarts
        if vRandomIndexs.count < 1 {
            vRandomIndexs = sorted((0 ..< xDim*yDim)) {_ in arc4random() % 2 == 0}
        }
        let randomIndex = vRandomIndexs.last ?? 0
        println("RANDCount: \(vRandomIndexs.count)")
        vRandomIndexs.removeLast()
        let battleOperation = shootAtPlayerId(allyPlayerId, index: randomIndex)
        vBattle = battleOperation.battle
        vBondAlly.updateBondArray(vBattle)
        if battleOperation.message == .Hit {
           vRandomIndexs = nearbyWaterForHit(randomIndex, randomIndexes: vRandomIndexs, board1D: vBondAlly.vBoard1D)
        }

    }

    // if a hit, look for all nearby positions
    private func nearbyWaterForHit(hitIndex: Int, randomIndexes: [Int], board1D: [Battle.SeaScape]) -> [Int] {
        
        var indexes: [Int] = []
        for i in [hitIndex+1, hitIndex-1, hitIndex+xDim, hitIndex-xDim] {
            if i < 0 || i >= self.xDim*self.yDim {
                continue
            }
            let seaDescription = board1D[i].description
            switch seaDescription {
            case "_", "A", "B", "S", "C", "P": indexes.append(i)
            default: ()
            }
        }

        var randomIndexesWithout = randomIndexes.filter {!contains(indexes,$0)}
        var newRandomIndexes = randomIndexesWithout + indexes
        return newRandomIndexes
    }


    // store a one dimentional dynamic array representing the board. This is a lot easier to handle than multiple dimensions
    // the view controller can listen for changes on the dynamic arrays and react to changes
    private class BondPlayer {
        let playerId: Battle.PlayerId
        private(set) var vBoard1D: [Battle.SeaScape]
        var listener: ([Int] -> Void)?

        init (battle: Battle, playerId: Battle.PlayerId) {
            self.playerId = playerId

            // get the starting state
            let board = battle.boardForPlayerId(playerId)
            vBoard1D = board.reduce([], combine: +)
        }
        
        func updateBondArray(battle: Battle) {
            let board = battle.boardForPlayerId(playerId)
            var arr = board.reduce([], combine: +)
            var vIndexes: [Int] = []
            for (idx, s) in enumerate(arr) {
                if (s != vBoard1D[idx]) {
                    vBoard1D[idx] = s
                    vIndexes.append(idx)
                }
            }
            if let callback = listener {
                callback(vIndexes)
            }
        }
    }

}