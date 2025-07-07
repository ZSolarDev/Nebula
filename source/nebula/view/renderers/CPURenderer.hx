package nebula.view.renderers;

import flixel.*;

class CPURenderer extends FlxSprite implements ViewRenderer
{
	public var view:N3DView;

	public function new(view:N3DView)
	{
		super(0, 0);
		this.view = view;
		makeGraphic(view.width, view.height, 0x000000);
		FlxG.state.add(this);
	}

	public function render()
	{
		// TODO: implement cpu rendering
	}
}
