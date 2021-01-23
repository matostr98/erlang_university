-module(db_update_handler).
-behavior(cowboy_handler).

-export([
	init/2,
	allowed_methods/2,
	content_types_provided/2,
	% db_to_json/2,
	db_to_text/2
]).

-record(state, {op}).

init(Req, Opts) ->
	io:format("init ~n"),
	io:format("Opts: ~p~n",[Opts]),
    [Op | _] = Opts,
	io:format("Opts: ~p~n",[Op]),
    State = #state{op=Op},
    {cowboy_rest, Req, State}.

allowed_methods(Req, State) ->
    Methods = [<<"GET">>, <<"POST">>, <<"DELETE">>],
    {Methods, Req, State}.
content_types_provided(Req, State) ->
	io:format("content type state: ~p~n",[State]),
	io:format("content type state: ~p~n",[Req]),
    {[
    %   {<<"application/json">>, db_to_json},
      {<<"text/plain">>, db_to_text}
     ], Req, State}.

% db_to_json(Req, #state{op=Op} = State) ->
%     {Body, Req1, State1} = case Op of
%         % list ->
%         %     get_record_list(Req, State);
%         % get ->
%         %     get_one_record(Req, State);
%         help ->
%             get_help(Req, State)
%     end,
%     {Body, Req1, State1}.

db_to_text(Req, #state{op=Op} = State) ->
	io:format("Db to text opt: ~p~n",[Op]),
    {Body, Req1, State1} = case Op of
        list ->
            get_record_list_text(Req, State);
        % get ->
        %     get_one_record_text(Req, State);
        help ->
            get_help_text(Req, State)
    end,
    {Body, Req1, State1}.

% get_help(Req, State) ->
	
%     {ok, Recordfilename} = application:get_env(rest_update, records_file_name),
%     {ok, Statefilename} = application:get_env(rest_update, state_file_name),
%     Body = "{
%     \"/list\": \"return a list of record IDs\",
%     \"/get/ID\": \"retrieve a record by its ID\",
%     \"/create\": \"create a new record; return its ID\",
%     \"/update/ID\": \"update an existing record\",
%     \"records_file_name\": \"~s\",
%     \"state_file_name\": \"~s\",
% }",
%     Body1 = io_lib:format(Body, [Recordfilename, Statefilename]),
%     {Body1, Req, State}.

get_help_text(Req, State) ->
	io:format("Last one: ~n"),
	io:format("Recordfilenaem: ~p~n",[application:get_env(dance_club, records_file_name)]),
	{ok, Recordfilename} = application:get_env(dance_club, records_file_name),
    {ok, Statefilename} = application:get_env(dance_club, state_file_name),
	io:format("Statefilename: ~p~n",[Statefilename]),
    Body = "
- list: return a list of record IDs~n
- get:  retrieve a record by its ID~n
- create: create a new record; return its ID~n
- update:  update an existing record~n
- records_file_name: ~s~n
- state_file_name: ~s~n
",
io:format("Body: ~p~n",[Body]),
    Body1 = io_lib:format(Body, [Recordfilename, Statefilename]),
    {Body1, Req, State}.

get_record_list_text(Req, State) ->
    {ok, Recordfilename} = application:get_env(dance_club, records_file_name),
    dets:open_file(records_db, [{file, Recordfilename}, {type, set}]),
    F1 = fun (Item, Acc) -> Acc1 = [Item | Acc], Acc1 end,
    Items = dets:foldl(F1, [], records_db),
    dets:close(records_db),
    F2 = fun ({Id, Rec}, Acc) ->
                 Val = io_lib:format("- ~s: ~s~n", [Id, Rec]),
                 [Val | Acc]
         end,
    Items1 = lists:foldl(F2, [], Items),
    Items2 = lists:sort(Items1),
    Items3 = lists:flatten(lists:concat(Items2)),
    Body = "
list: ~p,
",
    Body1 = io_lib:format(Body, [Items3]),
    {Body1, Req, State}.
