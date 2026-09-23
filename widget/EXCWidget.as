package
{
	import flash.display.MovieClip;
	import flash.filters.DropShadowFilter;
	import flash.text.TextField;
	import flash.text.TextFieldAutoSize;
	import flash.text.TextFormat;

	// Explosives Cycler: строка на экране поверх HUD.
	// Грузится в HUDMenu через F4SE UI.Load, управляется из EXC:CyclerQuest
	// через UI.Invoke (SetText / SetStyle) и UI.Set (x, y, visible).
	// Точка (0, 0) клипа — якорь: левый / центр / правый край строки по Align.
	public class EXCWidget extends MovieClip
	{
		public var tf:TextField;
		// Маркер для Papyrus: UI.Get(путь + ".ready") as Bool == true — клип жив.
		public var ready:Boolean = true;
		private var align:int = 0;

		public function EXCWidget()
		{
			super();
			mouseEnabled = false;
			mouseChildren = false;
			tf = new TextField();
			tf.selectable = false;
			tf.mouseEnabled = false;
			tf.embedFonts = true;
			tf.autoSize = TextFieldAutoSize.LEFT;
			tf.defaultTextFormat = new TextFormat("$MAIN_Font", 22, 0xFFFFFF);
			tf.filters = [new DropShadowFilter(1.5, 45, 0, 1, 2, 2, 2)];
			tf.text = "";
			addChild(tf);
		}

		public function SetText(s:String):void
		{
			tf.text = s;
			Place();
		}

		// size — кегль, color — 0xRRGGBB, a — 0 слева, 1 по центру, 2 справа от якоря.
		public function SetStyle(size:Number, color:Number, a:Number):void
		{
			var f:TextFormat = new TextFormat("$MAIN_Font", size, uint(color));
			tf.defaultTextFormat = f;
			tf.setTextFormat(f);
			align = int(a);
			Place();
		}

		private function Place():void
		{
			if (align == 1)
			{
				tf.x = -tf.width / 2;
			}
			else if (align == 2)
			{
				tf.x = -tf.width;
			}
			else
			{
				tf.x = 0;
			}
			tf.y = 0;
		}
	}
}
