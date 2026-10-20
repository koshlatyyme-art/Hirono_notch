import Foundation
@testable import NotchBuddyCore

/// The rig.json produced by tools/rig/cut.py (Task 1).
enum RigFixture {
    static let json = """
    {"canvas":[586,774],"frames":{"full":[10.0,80.0,566.0,560.0],"portrait":[45.0,130.0,495.0,350.0]},
     "limits":{"body":3,"head":10,"headTurn":20,"arm":15,"antenna":25},
     "layers":[{"name":"arm","file":"arm.png","parent":"body","pivot":[394.0,445.0]},
               {"name":"alienSleep","file":"alienSleep.png","parent":"arm","pivot":[394.0,445.0],"opacityFrom":"sleep"},
               {"name":"body","file":"body.png","parent":null,"pivot":[292.5,620.0]},
               {"name":"head","file":"head.png","parent":"body","pivot":[292.5,470.0]},
               {"name":"heart","file":"heart.png","parent":"body","pivot":[347.5,480.0]},
               {"name":"antenna","file":"antenna.png","parent":"head","pivot":[127.5,215.0]}],
     "glows":[{"name":"heart","parent":"heart","center":[347.5,480.0],"radius":40.0,"color":"#FF7A2E","night":1.0},
              {"name":"antenna","parent":"antenna","center":[94.0,177.5],"radius":35.0,"color":"#FF8C3A","night":0.9}]}
    """

    static let rig = try! JSONDecoder().decode(Rig.self, from: Data(json.utf8))
}
