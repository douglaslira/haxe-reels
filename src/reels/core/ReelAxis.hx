package reels.core;

/**
 * Projection between screen space and a reel's travel/cross axes.
 * No per-frame allocation on the hot path.
 */
class ReelAxis {
	public final orientation:Orientation;
	public final direction:Direction;
	/** +1 forward, -1 reverse. */
	public final polarity:Int;
	public final mainProp:String;
	public final crossProp:String;
	public final feedEdge:String;

	var _vertical:Bool;

	function new(orientation:Orientation, direction:Direction) {
		this.orientation = orientation;
		this.direction = direction;
		_vertical = orientation == Vertical;
		mainProp = _vertical ? "y" : "x";
		crossProp = _vertical ? "x" : "y";
		polarity = direction == Forward ? 1 : -1;
		feedEdge = polarity > 0 ? "start" : "end";
	}

	public static function create(orientation:Orientation, direction:Direction):ReelAxis {
		return new ReelAxis(orientation, direction);
	}

	public static final VERTICAL_FORWARD:ReelAxis = create(Vertical, Forward);

	public function getMain(view:IPositionable):Float {
		return mainProp == "y" ? view.y : view.x;
	}

	public function setMain(view:IPositionable, v:Float):Void {
		if (mainProp == "y") view.y = v;
		else view.x = v;
	}

	public function addMain(view:IPositionable, d:Float):Void {
		if (mainProp == "y") view.y += d;
		else view.x += d;
	}

	public function getCross(view:IPositionable):Float {
		return crossProp == "x" ? view.x : view.y;
	}

	public function setCross(view:IPositionable, v:Float):Void {
		if (crossProp == "x") view.x = v;
		else view.y = v;
	}

	public function toLocal(width:Float, height:Float):{cross:Float, main:Float} {
		return _vertical
			? {cross: width, main: height}
			: {cross: height, main: width};
	}

	public function toScreen(cross:Float, main:Float):{x:Float, y:Float} {
		return _vertical ? {x: cross, y: main} : {x: main, y: cross};
	}
}
