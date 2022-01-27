state("Karlson"){}

startup
{
	vars.totalTime = 0d;
	vars.inTutorial = true;

	using (var prov = new Microsoft.CSharp.CSharpCodeProvider())
	{
		var param = new System.CodeDom.Compiler.CompilerParameters
		{
			GenerateInMemory = true,
			ReferencedAssemblies = { "LiveSplit.Core.dll", "System.dll", "System.Core.dll", "System.Xml.dll", "System.Xml.Linq.dll" }
		};

		string mono = File.ReadAllText(@"Components\mono.cs"), helpers = File.ReadAllText(@"Components\mono_helpers.cs");
		var asm = prov.CompileAssemblyFromSource(param, mono, helpers);
		vars.unity = Activator.CreateInstance(asm.CompiledAssembly.GetType("Unity.Game"));
	}

	if (timer.CurrentTimingMethod == TimingMethod.RealTime)
	{
		var mbox = MessageBox.Show(
			"Karlson 3D uses in-game time.\nWould you like to switch to it?",
			"LiveSplit | Karlson 3D",
			MessageBoxButtons.YesNo);

		if (mbox == DialogResult.Yes) timer.CurrentTimingMethod = TimingMethod.GameTime;
	}
}

onStart
{
	vars.totalTime = 0d;
	vars.inTutorial = true;
}

onSplit
{
	vars.inTutorial = false;
}

init
{
	vars.unity.TryOnLoad = (Func<dynamic, bool>)(helper =>
	{
		var _game = helper.GetClass("Assembly-CSharp", "Game");
		var _timer = helper.GetClass("Assembly-CSharp", "Timer");

		vars.unity.Make<bool>(_game.Static, _game["Instance"], _game["playing"]).Name = "playing";
		vars.unity.Make<bool>(_game.Static, _game["Instance"], _game["done"]).Name = "done";
		vars.unity.Make<float>(_timer.Static, _timer["Instance"], _timer["timer"]).Name = "timer";

		return true;
	});

	vars.unity.Load(game);
}

update
{
	if (!vars.unity.Loaded) return false;

	vars.unity.Watchers.UpdateAll(game);

	current.playing = vars.unity.Watchers["playing"].Current;
	current.done = vars.unity.Watchers["done"].Current;
	current.timer = vars.unity.Watchers["timer"].Current;
}

start
{
	return !old.playing && current.playing || old.timer > current.timer;
}

split
{
	return !old.done && current.done;
}

reset
{
	return old.timer > current.timer && vars.inTutorial;
}

gameTime
{
	if (old.timer > current.timer)
		vars.totalTime += Math.Round(old.timer, 2);

	return TimeSpan.FromSeconds(vars.totalTime + Math.Round(current.timer, 2));
}

isLoading
{
	return true;
}

exit
{
	vars.unity.Reset();
}

shutdown
{
	vars.unity.Reset();
}
