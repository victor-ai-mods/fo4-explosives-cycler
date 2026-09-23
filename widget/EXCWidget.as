package
{
	import flash.display.Graphics;
	import flash.display.MovieClip;
	import flash.display.Shape;
	import flash.display.Sprite;
	import flash.filters.DropShadowFilter;
	import flash.text.TextField;
	import flash.text.TextFieldAutoSize;
	import flash.text.TextFormat;

	// Explosives Cycler: строка на экране поверх HUD.
	// Грузится в HUDMenu через F4SE UI.Load, управляется из EXC:CyclerQuest
	// через UI.Invoke (SetText / SetStyle) и UI.Set (x, y, visible).
	// Точка (0, 0) клипа — якорь: левый / центр / правый край строки по Align.
	// Метки [grenade], [mine], [molotov] в тексте (регистр любой) рисуются значками
	// цвета текста; контуры — блок ICONS, его пишет tools/gen_icons.py.
	public class EXCWidget extends MovieClip
	{
		// BEGIN ICONS (tools/gen_icons.py, не править руками)
		// Контур: ширина, высота, затем 1 x y — moveTo, 2 x y — lineTo, 3 cx cy x y — curveTo.
		private static const ICONS:Object = {
			grenade: [
			28, 28.95, 1, 23, 9.6, 2, 13.3, 9.6, 2, 13.75, 7.15, 2, 10.95, 7.2, 3, 11.05, 9.55, 10, 11, 3, 9.1, 12.25, 7.2, 13,
			3, 6.5, 15.85, 6.4, 19.75, 2, 6.25, 20.9, 2, 5.75, 21.55, 2, 5.2, 21.5, 2, 4.75, 21.25, 3, 4.55, 21, 4.6, 20.4, 2, 4.65,
			19.25, 3, 4.65, 16.75, 5.05, 13.25, 2, 4.4, 13.05, 2, 3.75, 12.9, 3, 2.1, 12.35, 1.1, 10.9, 3, 0, 9.25, 0.2, 7.15, 3, 0.4,
			5.2, 1.9, 3.8, 3, 3.45, 2.4, 5.55, 2.35, 3, 7.65, 2.35, 9.1, 3.7, 2, 10.55, 2.55, 2, 12.1, 1.2, 2, 13.1, 0.4, 3, 13.7,
			0, 14.4, 0.05, 2, 22.45, 0.05, 3, 23.3, 0.05, 23.65, 0.4, 3, 24.05, 0.85, 24.15, 2.25, 2, 24.15, 3.65, 2, 22.05, 3.65, 2, 23,
			9.6, 1, 24.6, 10.8, 3, 25.5, 10.95, 25.95, 11.55, 2, 26.9, 13.4, 2, 27.55, 15.6, 2, 23.4, 15.6, 3, 23.25, 13.1, 22.45, 10.85, 2,
			22.5, 10.8, 2, 24.6, 10.8, 1, 23.5, 19.2, 2, 23.4, 16.75, 2, 27.65, 16.75, 3, 28, 18.65, 27.15, 21.55, 2, 23.25, 21.55, 2, 23.5,
			19.2, 1, 22.25, 21.55, 2, 14.3, 21.55, 2, 14.05, 19.2, 3, 14, 17.8, 14.1, 16.75, 2, 22.35, 16.75, 2, 22.35, 19.2, 2, 22.25, 21.55,
			1, 26.65, 22.75, 3, 24.95, 26.85, 20.95, 28.3, 2, 22.2, 25.7, 2, 23.1, 22.75, 2, 26.65, 22.75, 1, 22.25, 15.6, 2, 14.2, 15.6, 3,
			14.45, 12.35, 15.2, 10.8, 2, 21.3, 10.8, 3, 22.05, 12.85, 22.25, 15.6, 1, 11.7, 10.8, 2, 12.75, 10.8, 2, 13.9, 10.8, 3, 13.05, 13.3,
			12.95, 15.6, 2, 8.9, 15.6, 3, 9.1, 14.25, 9.95, 12.5, 2, 10.65, 11.45, 3, 11.05, 10.9, 11.7, 10.8, 1, 5.45, 4.35, 3, 4.25, 4.4,
			3.25, 5.2, 3, 2.3, 6.1, 2.15, 7.4, 3, 2, 8.95, 2.9, 10, 3, 3.8, 11, 5.35, 11.25, 3, 5.75, 9.3, 6.1, 8.3, 3, 6.6,
			6.75, 7.3, 5.85, 2, 8.15, 7.1, 2, 9, 8.3, 3, 9.1, 6.5, 8.05, 5.35, 3, 7.05, 4.3, 5.45, 4.35, 1, 8.6, 19.25, 3, 8.45,
			17.8, 8.7, 16.75, 2, 12.75, 16.75, 2, 13.05, 21.55, 2, 9.1, 21.55, 2, 8.6, 19.25, 1, 14.45, 22.75, 2, 21.9, 22.75, 2, 20.8, 26.35,
			3, 19.5, 28.95, 17.85, 28.75, 3, 16.65, 28.6, 15.6, 26.35, 3, 14.95, 25.05, 14.45, 22.9, 2, 14.4, 22.8, 2, 14.45, 22.75, 1, 13.15, 22.75,
			3, 13.6, 25.65, 15.3, 28.3, 3, 11.45, 26.95, 9.5, 22.75, 2, 13.15, 22.75
			],
			mine: [
			29.1, 29.05, 1, 24.7, 10.7, 3, 25.5, 12.45, 24.75, 13.2, 2, 22.3, 13.1, 3, 20.5, 12.25, 18.7, 10.4, 3, 16.8, 8.5, 15.95, 6.8, 3,
			15.2, 4.9, 15.85, 4.25, 2, 18.4, 4.35, 3, 20.15, 5.15, 22.05, 7, 3, 23.9, 8.85, 24.7, 10.7, 1, 28.1, 24.5, 2, 27, 25.15, 3,
			25.45, 25.25, 22.85, 24.3, 3, 17.8, 22.5, 12.45, 17.15, 3, 6.75, 11.45, 4.8, 6.5, 3, 3.05, 2.5, 4.55, 1, 3, 5.55, 0, 7.75, 0.25,
			3, 9.85, 0.5, 12.6, 2, 3, 14.15, 2.2, 15.85, 3.25, 3, 15.5, 3.35, 15.25, 3.65, 3, 14.8, 4.1, 14.75, 4.8, 3, 14.55, 5.75, 15.2,
			7.1, 3, 16.05, 9, 18.05, 11, 3, 20, 12.95, 21.95, 13.85, 3, 23.3, 14.45, 24.25, 14.35, 3, 24.95, 14.25, 25.4, 13.8, 2, 25.75, 13.2,
			3, 26.9, 14.95, 27.05, 16.45, 3, 28.55, 19.15, 28.75, 21.25, 3, 29.1, 23.5, 28.1, 24.5, 1, 2.9, 2.35, 3, 2.6, 4.65, 4, 7.9, 3,
			5.05, 10.3, 7, 12.9, 3, 8.8, 15.4, 11.25, 17.85, 2, 16.2, 22.1, 3, 18.75, 24, 21.1, 25.05, 3, 24.2, 26.5, 26.45, 26.15, 2, 23.05,
			28.2, 3, 20.8, 29.05, 16.7, 26.9, 3, 12.5, 24.75, 8.4, 20.65, 3, 4.25, 16.5, 2.1, 12.35, 3, 0, 8.25, 0.85, 5.95, 2, 2.9, 2.35
			],
			molotov: [
			20.67, 31.07, 1, 12.23, 9.09, 2, 15.5, 10.61, 2, 14.06, 13.69, 3, 13.55, 14.78, 14.67, 16.18, 3, 16.24, 18.02, 15.22, 20.19, 2, 10.83, 29.62,
			3, 10.15, 31.07, 8.7, 30.39, 2, 1.45, 27.01, 3, 0, 26.33, 0.68, 24.88, 2, 5.07, 15.46, 3, 6.09, 13.28, 8.5, 13.31, 3, 10.29, 13.26,
			10.8, 12.17, 1, 5.77, 18.21, 2, 12.66, 21.42, 2, 10.46, 26.14, 2, 3.58, 22.93, 1, 12.54, 7.02, 2, 16.89, 9.05, 2, 16.38, 10.14, 2,
			12.03, 8.11, 1, 14.96, 7.49, 3, 10.88, 5.37, 12.6, 2.64, 3, 13.89, 0.81, 15.84, 0.4, 3, 14.73, 2.31, 15.48, 3.54, 3, 16.92, 0.46, 20.67,
			0, 3, 18.67, 2.38, 19.45, 4.51, 3, 20.22, 6.63, 19.08, 7.65, 3, 17.64, 8.85, 14.96, 7.49, 1, 15.43, 6.5, 3, 13.93, 5.69, 14.66, 4.59,
			3, 15.22, 3.86, 16.29, 3.7, 3, 15.88, 4.83, 16.66, 5.75, 3, 17.27, 6.58, 16.96, 6.77, 3, 16.38, 7.05, 15.43, 6.5
			]
		};
		// END ICONS

		// Размеры — доли кегля: значок вписан в квадрат ICON_BOX; промежуток между
		// значками подряд, между значком и текстом вплотную и через пробел.
		private static const ICON_BOX:Number = 1.0;
		private static const GAP_ICONS:Number = 0.12;
		private static const GAP_TIGHT:Number = 0.08;
		private static const GAP_SPACE:Number = 0.3;
		// Поле TextField шире текста на 2 px с каждой стороны.
		private static const GUTTER:Number = 2;

		// Маркер для Papyrus: UI.Get(путь + ".ready") as Bool == true — клип жив.
		public var ready:Boolean = true;
		private var line:Sprite;
		private var text:String = "";
		private var fontSize:Number = 22;
		private var color:uint = 0xFFFFFF;
		private var align:int = 0;

		// Состояние раскладки в Build: правый край, что было последним (0 — ничего,
		// 1 — текст, 2 — значок), был ли после него пробел, высота строки.
		private var cx:Number = 0;
		private var prevKind:int = 0;
		private var spacePending:Boolean = false;
		private var lineH:Number = 0;

		public function EXCWidget()
		{
			super();
			mouseEnabled = false;
			mouseChildren = false;
			line = new Sprite();
			line.mouseEnabled = false;
			line.mouseChildren = false;
			line.filters = [new DropShadowFilter(1.5, 45, 0, 1, 2, 2, 2)];
			addChild(line);
		}

		public function SetText(s:String):void
		{
			text = s == null ? "" : s;
			Build();
		}

		// size — кегль, color — 0xRRGGBB, a — 0 слева, 1 по центру, 2 справа от якоря.
		public function SetStyle(size:Number, c:Number, a:Number):void
		{
			fontSize = size;
			color = uint(c);
			align = int(a);
			Build();
		}

		private function Build():void
		{
			while (line.numChildren > 0)
			{
				line.removeChildAt(0);
			}
			lineH = MakeField("0").height;
			cx = 0;
			prevKind = 0;
			spacePending = false;
			var start:int = 0;
			var i:int = 0;
			while (i < text.length)
			{
				if (text.charAt(i) == "[")
				{
					var close:int = text.indexOf("]", i);
					if (close > i)
					{
						var name:String = text.substring(i + 1, close).toLowerCase();
						if (ICONS.hasOwnProperty(name))
						{
							AddText(text.substring(start, i));
							AddIcon(ICONS[name]);
							i = close + 1;
							start = i;
							continue;
						}
					}
				}
				i++;
			}
			AddText(text.substring(start));
			Place();
		}

		private function MakeField(s:String):TextField
		{
			var tf:TextField = new TextField();
			tf.selectable = false;
			tf.mouseEnabled = false;
			tf.embedFonts = true;
			tf.autoSize = TextFieldAutoSize.LEFT;
			tf.defaultTextFormat = new TextFormat("$MAIN_Font", fontSize, color);
			tf.text = s;
			return tf;
		}

		private static function IsSpace(ch:String):Boolean
		{
			return ch == " " || ch == "\t" || ch == String.fromCharCode(160);
		}

		// Промежуток перед следующим куском строки.
		private function Gap(nextIsIcon:Boolean):Number
		{
			if (prevKind == 0)
			{
				return 0;
			}
			if (spacePending)
			{
				return fontSize * GAP_SPACE;
			}
			if (nextIsIcon && prevKind == 2)
			{
				return fontSize * GAP_ICONS;
			}
			return fontSize * GAP_TIGHT;
		}

		private function AddText(s:String):void
		{
			var a:int = 0;
			var b:int = s.length;
			while (a < b && IsSpace(s.charAt(a)))
			{
				a++;
			}
			while (b > a && IsSpace(s.charAt(b - 1)))
			{
				b--;
			}
			if (a > 0 || (b == a && s.length > 0))
			{
				spacePending = true;
			}
			if (b == a)
			{
				return;
			}
			cx += Gap(false);
			var tf:TextField = MakeField(s.substring(a, b));
			tf.x = cx - GUTTER;
			tf.y = 0;
			line.addChild(tf);
			cx += tf.width - 2 * GUTTER;
			prevKind = 1;
			spacePending = b < s.length;
		}

		// d — контур из ICONS: ширина, высота, затем команды (см. блок ICONS).
		private function AddIcon(d:Array):void
		{
			cx += Gap(true);
			var w:Number = d[0];
			var h:Number = d[1];
			var k:Number = fontSize * ICON_BOX / Math.max(w, h);
			var sh:Shape = new Shape();
			var g:Graphics = sh.graphics;
			g.beginFill(color, 1);
			var i:int = 2;
			while (i < d.length)
			{
				var c:int = d[i];
				if (c == 1)
				{
					g.moveTo(d[i + 1] * k, d[i + 2] * k);
					i += 3;
				}
				else if (c == 2)
				{
					g.lineTo(d[i + 1] * k, d[i + 2] * k);
					i += 3;
				}
				else
				{
					g.curveTo(d[i + 1] * k, d[i + 2] * k, d[i + 3] * k, d[i + 4] * k);
					i += 5;
				}
			}
			g.endFill();
			sh.x = cx;
			sh.y = (lineH - h * k) / 2;
			line.addChild(sh);
			cx += w * k;
			prevKind = 2;
			spacePending = false;
		}

		private function Place():void
		{
			if (align == 1)
			{
				line.x = -cx / 2;
			}
			else if (align == 2)
			{
				line.x = -cx;
			}
			else
			{
				line.x = 0;
			}
			line.y = 0;
		}
	}
}
