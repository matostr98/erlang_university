-module(dance_club_app).
-behaviour(application).

-export([start/2]).
-export([stop/1]).

start(_Type, _Args) ->
	    Dispatch = cowboy_router:compile([
        {'_', [
               {"/list", db_update_handler, [list]},
            %    {"/get/:record_id", db_update_handler, [get]},
            %    {"/create", db_update_handler, [create]},
            %    {"/update/:record_id", db_update_handler, [update]},
            %    {"/delete/:record_id", db_update_handler, [delete]},
               {"/help", db_update_handler, [help]},
               {"/", db_update_handler, [help]}
              ]}
    ]),
    {ok, _} = cowboy:start_clear(my_http_listener,
        [{port, 8080}],
        #{env => #{dispatch => Dispatch}}
    ),
	dance_club_sup:start_link().

stop(_State) ->
	ok.
