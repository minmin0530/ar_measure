//
//  ViewController.swift
//  Measure002
//
//  Created by 泉芳樹 on 2021/04/20.
//

import UIKit
import ARKit

class ViewController: UIViewController, ARSCNViewDelegate {

    private var startNode: SCNNode?
    private var endNode: SCNNode?
    private var lineNode: SCNNode?
    
    @IBOutlet weak var sceneView: ARSCNView!
    @IBOutlet weak var trackingStateLabel: UILabel!
    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var resetButton: UIButton!
    override func viewDidLoad() {
        super.viewDidLoad()
        
        sceneView.delegate = self
        sceneView.debugOptions = [SCNDebugOptions.showFeaturePoints]
        sceneView.scene = SCNScene()

        reset()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = .horizontal
        config.isLightEstimationEnabled = true
        sceneView.session.run( config, options: [.resetTracking, .removeExistingAnchors] )
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        sceneView.session.pause()
    }

    private func putSphere(at pos: SCNVector3, color: UIColor) -> SCNNode {
        let node = SCNNode.sphereNode(color: color)
        sceneView.scene.rootNode.addChildNode(node)
        node.position = pos
        return node
    }

    private func drawLine(from: SCNNode, to: SCNNode, length: Float) -> SCNNode {
        let lineNode = SCNNode.lineNode(length: CGFloat(length), color: .red)
        from.addChildNode(lineNode)
        lineNode.position = SCNVector3Make(0, 0, -length / 2)
        from.look(at: to.position)
        return lineNode
    }
    
    func reset() {
        startNode?.removeFromParentNode()
        startNode = nil
        endNode?.removeFromParentNode()
        endNode = nil
        statusLabel.isHidden = true
    }
    
    private func hitTest(_ pos: CGPoint) {
        let results = sceneView.hitTest(pos, types: [.existingPlane])
        guard let result = results.first else {
            return
        }
        let hitPos = result.worldTransform.position()
        
        if let startNode = startNode {
            endNode = putSphere(at: hitPos, color: .green)
            guard let endNode = endNode else {
                fatalError()
            }
            
            let distance = (endNode.position - startNode.position).length()
            print("distance \(distance) [m]")
            
            lineNode = drawLine(from: startNode, to: endNode, length: distance)
            
            statusLabel.text = String(format: "Distance: %.2f [m]", distance)
            
        } else {
            startNode = putSphere(at: hitPos, color: .blue)
            statusLabel.text = "Tap an end point"
        }
    }

    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        guard let frame = sceneView.session.currentFrame else {
            return
        }
        DispatchQueue.main.async(execute: {
            self.statusLabel.isHidden = !(frame.anchors.count > 0)
            if self.startNode == nil {
                self.statusLabel.text = "Tap a start point"
            }
        })
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        guard let planeAnchor = anchor as? ARPlaneAnchor else {
            fatalError()
        }
        planeAnchor.addPlaneNode(on: node, contents: UIColor.arBlue.withAlphaComponent(0.1))
    }

    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard let planeAnchor = anchor as? ARPlaneAnchor else {
            fatalError()
        }
        planeAnchor.updatePlaneNode(on: node)
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didRemove node: SCNNode, for anchor: ARAnchor) {
        print("\(self.classForCoder)/" + #function)
    }
    
    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        print("trackingState: \(camera.trackingState)")
        trackingStateLabel.text = camera.trackingState.description
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else {
            return
        }
        let pos = touch.location(in: sceneView)
        
        if let endNode = endNode {
            endNode.removeFromParentNode()
            lineNode?.removeFromParentNode()
        }
        
        hitTest(pos)
    }
    
    @IBAction func resetButtonTapped(_ sender: Any) {
        reset()
    }
    
}

extension ARCamera.TrackingState {
    public var description: String {
        switch self {
        case .notAvailable:
            return "TRACKING UNAVAILABLE"
        case .normal:
            return "TRACKING NORMAL"
        case .limited(let reason):
            switch reason {
            case .excessiveMotion:
                return "TRACKING LIMITED\nToo much camera movement"
            case .insufficientFeatures:
                return "TRACKING LIMITED\nNot enough surface detail"
            case .initializing:
                return "TRACKING LIMITED\nInitialization in progress"
            case .relocalizing:
                return "TRACKING LIMITED\nRelocalization in progress"
            @unknown default:
                fatalError()
            }
        }
    }
}

extension UIColor {
    class var arBlue: UIColor {
        get {
            return UIColor(red: 0.1, green: 0.5, blue: 0.8, alpha: 1)
        }
    }
}
extension ARPlaneAnchor {
    
    @discardableResult
    func addPlaneNode(on node: SCNNode, geometry: SCNGeometry, contents: Any) -> SCNNode {
        guard let material = geometry.materials.first else {
            fatalError()
        }
        if let program = contents as? SCNProgram {
            material.program = program
        } else {
            material.diffuse.contents = contents
        }
        
        let planeNode = SCNNode(geometry: geometry)
        
        DispatchQueue.main.async(execute: {
            node.addChildNode(planeNode)
        })
        return planeNode
    }
    func addPlaneNode(on node: SCNNode, contents: Any) {
        let geometry = SCNPlane(width: CGFloat(extent.x), height: CGFloat(extent.z))
        let planeNode = addPlaneNode(on: node, geometry: geometry, contents: contents)
        planeNode.transform = SCNMatrix4MakeRotation(-Float.pi / 2.0, 1, 0, 0)
    }
    
    func findPlaneNode(on node: SCNNode) -> SCNNode? {
        for childNode in node.childNodes {
            if childNode.geometry as? SCNPlane != nil {
                return childNode
            }
        }
        return nil
    }
    
    func updatePlaneNode(on node: SCNNode) {
        DispatchQueue.main.async(execute: {
            guard let plane = self.findPlaneNode(on: node)?.geometry as? SCNPlane else {
                return
            }
            guard !PlaneSizeEqualToExtent(plane: plane, extent: self.extent) else { return }
            plane.width = CGFloat(self.extent.x)
            plane.height = CGFloat(self.extent.z)
        })
    }
}

fileprivate func PlaneSizeEqualToExtent(plane: SCNPlane, extent: vector_float3) -> Bool {
    if plane.width != CGFloat(extent.x) || plane.height != CGFloat(extent.z) {
        return false
    } else {
        return true
    }
}


func - (left: SCNVector3, right: SCNVector3) -> SCNVector3 {
    return SCNVector3Make(left.x - right.x, left.y - right.y, left.z - right.z)
}

extension SCNVector3 {
    func length() -> Float {
        return sqrtf(x * x + y * y + z * z)
    }
}
extension matrix_float4x4 {
    func position() -> SCNVector3 {
        let mat = SCNMatrix4(self)
        return SCNVector3(mat.m41, mat.m42, mat.m43)
    }
}
extension SCNNode {
    class func sphereNode(color: UIColor) -> SCNNode {
        let geometry = SCNSphere(radius: 0.01)
        geometry.materials.first?.diffuse.contents = color
        return SCNNode(geometry: geometry)
    }
    
    class func lineNode(length: CGFloat, color: UIColor) -> SCNNode {
        let geometry = SCNCapsule(capRadius: 0.004, height: length)
        geometry.materials.first?.diffuse.contents = color
        let line = SCNNode(geometry: geometry)
        
        let node = SCNNode()
        node.eulerAngles = SCNVector3Make(Float.pi/2, 0, 0)
        node.addChildNode(line)
        
        return node
    }
}
