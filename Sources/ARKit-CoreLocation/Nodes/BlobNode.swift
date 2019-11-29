//
//  BlobNode.swift
//  ARCL
//
//  Created by Marc Alexander on 11/27/19.
//

import Foundation
import CoreLocation
import ARKit

public class BlobNode: LocationNode {

	public init(coords: [CLLocationCoordinate2D], floor: CLLocationDistance, height: CLLocationDistance, color: UIColor) {
		print(#function)
		super.init(location: CLLocation(coordinate: BlobNode.centerPoint(coords: coords), altitude: floor))

//		print("center: \(center.coordinate.latitude),\(center.coordinate.longitude)")

		let path = pointsToPath(coords: coords)									// Convert [coord] to Bezier Path

		let geometry = SCNShape(path: path, extrusionDepth: CGFloat(height))	// The node's geometry
		geometry.firstMaterial?.diffuse.contents = color

		let shapeNode = SCNNode(geometry: geometry)					// Attach geometry to shape node
		shapeNode.name = ""
		shapeNode.removeFlicker()

		shapeNode.eulerAngles.x = Float.pi / 2						// Pitch: rotation about the node’s x-axis (topple over the blob)
		shapeNode.eulerAngles.y = 0 - Float.pi / 4					// Yaw:   rotation about the node’s y-axis (rotate for North up)
//		shapeNode.eulerAngles.z = Float.pi / 4						// Roll:  rotation about the node’s z-axis

		addChildNode(shapeNode)										// Attach shape node to ourself

	} // init(coords:floor:height:color:)

	required public init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	deinit {
		print(#function)

	} // deinit

	class func centerPoint (coords: [CLLocationCoordinate2D]) -> CLLocationCoordinate2D {

        let latitude: CLLocationDegrees = (coords.reduce(0) {accumulator, coord in coord.latitude + accumulator}) / Double(coords.count)
        let longitude: CLLocationDegrees = (coords.reduce(0) {accumulator, coord in coord.longitude + accumulator}) / Double(coords.count)

        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)

	} // centerPoint (coords:) -> CLLocationCoordinate2D

	func pointsToPath (coords: [CLLocationCoordinate2D]) -> UIBezierPath {

		let path = UIBezierPath()

		for (index, coord) in coords.enumerated() {

			let distance = location.distance(from: CLLocation.init(coordinate: coord, altitude: location.altitude))
			let bearing = location.bearing(between: CLLocation.init(coordinate: coord, altitude: location.altitude))
			let theta = 90 - bearing

			let x = cos(theta) * distance								//  Convert lat-lng to CGPoint in meters from the reference point
			let y = 0 + sin(theta) * distance							// ...
			let point = CGPoint(x: x, y: y);							// ...

			print("\(index): \(coord) | \(point) | \(distance.metersToNauticalMiles.short) | \(bearing.short) | \(theta.short)")

			if index == 0	 					{ path.move(to: point) }			// First point
			else								{ path.addLine(to: point) }			// Subsequent points

		} // foreach point

		path.close()

		return path

	} // pointsToPath(coords:) -> UIBezierPath

} // BlobNode class
