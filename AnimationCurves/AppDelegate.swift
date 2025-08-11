import SwiftUI
import UIKit
import Wave

let duration: CGFloat = 5
let bounce: CGFloat = 0.4

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
	func application(
		_: UIApplication,
		didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]?,
	) -> Bool {
		true
	}

	func application(
		_: UIApplication,
		configurationForConnecting connectingSceneSession: UISceneSession,
		options _: UIScene.ConnectionOptions,
	) -> UISceneConfiguration {
		UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
	}
}

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
	var window: UIWindow?

	func scene(_ scene: UIScene, willConnectTo _: UISceneSession, options _: UIScene.ConnectionOptions) {
		window = UIWindow(windowScene: scene as! UIWindowScene)
		window!.rootViewController = ViewController()
		window!.makeKeyAndVisible()
	}
}

final class ViewController: UIViewController {
	private var tracks = [Curve: Track]()
	private var moved = false
	private var dynamicAnimator: UIDynamicAnimator!
	private var behavior: UIAttachmentBehavior!

	override func loadView() {
		super.loadView()
		view.backgroundColor = .systemBackground

		var trackStacks = [UIStackView]()
		for curve in Curve.allCases {
			let track = Track()
			tracks[curve] = track

			let label = UILabel()
			label.text = curve.description
			label.textAlignment = .right
			label.numberOfLines = 0

			let stack = UIStackView(arrangedSubviews: [label, track])
			stack.spacing = 20
			trackStacks.append(stack)

			NSLayoutConstraint.activate([
				label.widthAnchor.constraint(equalToConstant: 100),
			])
		}

		let stackView = UIStackView(arrangedSubviews: trackStacks)
		stackView.axis = .vertical
		stackView.spacing = 10

		let button = UIButton(
			configuration: .borderedProminent(),
			primaryAction: UIAction(title: "Toggle") { [weak self] _ in
				guard let self else { return }
				for (curve, track) in tracks {
					let trackWidth = track.bounds.width
					let trackMidY = track.bounds.midY
					let ballRadius = track.ball.frame.width / 2

					let newBallCenter = moved
						? CGPoint(x: ballRadius, y: trackMidY)
						: CGPoint(x: trackWidth - ballRadius, y: trackMidY)

					guard curve != .wave else {
						let spring = Spring(dampingRatio: 1 - bounce, response: duration)
						Wave.animate(withSpring: spring) { track.ball.animator.center = newBallCenter }
						continue
					}

					guard curve != .dynamics else {
						if dynamicAnimator == nil {
							dynamicAnimator = UIDynamicAnimator(referenceView: track)
							behavior = UIAttachmentBehavior(item: track.ball, attachedToAnchor: track.ball.center)
							behavior.length = 0
							behavior.damping = 1 - bounce
							behavior.frequency = 1 / duration
							dynamicAnimator.addBehavior(behavior)
						}
						behavior.anchorPoint = newBallCenter
						continue
					}

					curve.animate { track.ball.center = newBallCenter }
				}
				moved = !moved
			},
		)

		stackView.translatesAutoresizingMaskIntoConstraints = false
		button.translatesAutoresizingMaskIntoConstraints = false
		view.addSubview(stackView)
		view.addSubview(button)

		NSLayoutConstraint.activate([
			stackView.leadingAnchor.constraint(equalTo: view.readableContentGuide.leadingAnchor),
			stackView.trailingAnchor.constraint(equalTo: view.readableContentGuide.trailingAnchor),
			stackView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
			button.centerXAnchor.constraint(equalTo: view.centerXAnchor),
			button.bottomAnchor.constraint(equalTo: view.layoutMarginsGuide.bottomAnchor),
		])
	}

	override func viewDidLoad() {
		super.viewDidLoad()
	}
}

final class Track: UIView {
	let ball: UIView

	init() {
		let diameter: CGFloat = 50
		ball = UIView()
		ball.backgroundColor = .systemYellow
		ball.layer.cornerRadius = diameter / 2

		super.init(frame: .zero)

		ball.translatesAutoresizingMaskIntoConstraints = false
		addSubview(ball)

		NSLayoutConstraint.activate([
			ball.widthAnchor.constraint(equalToConstant: diameter),
			ball.heightAnchor.constraint(equalToConstant: diameter),
			ball.topAnchor.constraint(equalTo: topAnchor),
			ball.bottomAnchor.constraint(equalTo: bottomAnchor),
			ball.leadingAnchor.constraint(equalTo: leadingAnchor),
		])
	}

	@available(*, unavailable)
	required init?(coder _: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
}

enum Curve: CaseIterable, CustomStringConvertible {
	case linear
	case easeInOut
	case easeIn
	case easeOut
	case spring
	case easeInSpring
	case swiftUI
	case wave
	case dynamics

	var description: String {
		switch self {
		case .linear: "Linear"
		case .easeInOut: "Ease In Out"
		case .easeIn: "Ease In"
		case .easeOut: "Ease Out"
		case .spring: "Spring"
		case .easeInSpring: "Ease In Spring"
		case .swiftUI: "SwiftUI"
		case .wave: "Wave"
		case .dynamics: "Dynamics"
		}
	}

	func animate(_ animations: @escaping () -> Void) {
		guard self != .swiftUI else {
			UIView.animate(.interactiveSpring(response: duration, dampingFraction: 1 - bounce), changes: animations)
			return
		}

		let timingParameters: any UITimingCurveProvider = switch self {
		case .linear: UICubicTimingParameters(animationCurve: .linear)
		case .easeInOut: UICubicTimingParameters(animationCurve: .easeInOut)
		case .easeIn: UICubicTimingParameters(animationCurve: .easeIn)
		case .easeOut: UICubicTimingParameters(animationCurve: .easeOut)
		case .spring: UISpringTimingParameters(duration: duration, bounce: bounce)
		case .easeInSpring: CompositeTimingParameters(duration: duration, bounce: bounce)
		case .swiftUI, .wave, .dynamics: preconditionFailure()
		}

		let animator = UIViewPropertyAnimator(duration: duration, timingParameters: timingParameters)
		animator.addAnimations(animations)
		animator.startAnimation()
	}
}

final class CompositeTimingParameters: NSObject, UITimingCurveProvider {
	private static let durationKey = "Duration"
	private static let bounceKey = "Bounce"

	let duration: CGFloat
	let bounce: CGFloat

	init(duration: CGFloat, bounce: CGFloat) {
		self.duration = duration
		self.bounce = bounce
	}

	init?(coder: NSCoder) {
		duration = coder.decodeDouble(forKey: CompositeTimingParameters.durationKey)
		bounce = coder.decodeDouble(forKey: CompositeTimingParameters.bounceKey)
	}

	var timingCurveType: UITimingCurveType { .composed }

	var cubicTimingParameters: UICubicTimingParameters? {
		UICubicTimingParameters(animationCurve: .easeIn)
	}

	var springTimingParameters: UISpringTimingParameters? {
		let springAnimation = CASpringAnimation(perceptualDuration: duration, bounce: bounce)
		return UISpringTimingParameters(
			mass: springAnimation.mass,
			stiffness: springAnimation.stiffness,
			damping: springAnimation.damping,
			initialVelocity: .zero,
		)
	}

	func copy(with _: NSZone? = nil) -> Any {
		CompositeTimingParameters(duration: duration, bounce: bounce)
	}

	func encode(with coder: NSCoder) {
		coder.encode(duration, forKey: CompositeTimingParameters.durationKey)
		coder.encode(bounce, forKey: CompositeTimingParameters.bounceKey)
	}
}
