{application, 'dance_club', [
	{description, "New project"},
	{vsn, "0.1.0"},
	{modules, ['dance_club_app','dance_club_sup','db_update_handler']},
	{registered, [dance_club_sup]},
	{applications, [kernel,stdlib,cowboy]},
	{mod, {dance_club_app, []}},
	{env, []}
]}.