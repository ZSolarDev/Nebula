package nebula.view.renderers;

interface ViewRenderer
{
	public var view:N3DView;
	public var rendering:Bool;
	public function renderScene():Void;
}
