-module(db_update_handler).
-behavior(cowboy_handler).

-export([
	init/2,
	allowed_methods/2,
	content_types_provided/2,
	content_types_accepted/2,
	% db_to_json/2,
	db_to_text/2,
	text_to_db/2,
	resource_exists/2,
	delete_resource/2
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

content_types_accepted(Req, State) ->
    {[
      {<<"text/plain">>, text_to_db},
      %{<<"application/json">>, text_to_db}
      {<<"application/x-www-form-urlencoded">>, text_to_db}
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
        get ->
            get_one_record_text(Req, State);
        help ->
            get_help_text(Req, State)
    end,
    {Body, Req1, State1}.



text_to_db(Req, #state{op=Op} = State) ->
	io:format("text to db: ~p~n",[Op]),
    {Body, Req1, State1} = case Op of
        create ->
            create_record_to_json(Req, State);
        delete ->
            delete_record_to_json(Req, State);
        update ->
            update_record_to_json(Req, State)
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
	% {ok, Statefilename} = application:get_env(dance_club, state_file_name),
	% dets:open_file(records_db, [{file, Statefilename}, {type, set}]),
	io:format("in get fun:~n"),
    F1 = fun (Item, Acc) -> Acc1 = [Item | Acc], Acc1 end,
    Items = dets:foldl(F1, [], records_db),
	io:format("Items: : ~p~n", [Items]),
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

get_one_record_text(Req, State) ->
    RecordId = cowboy_req:binding(record_id, Req),
    RecordId1 = binary_to_list(RecordId),
    {ok, Recordfilename} = application:get_env(dance_club, records_file_name),
    {ok, _} = dets:open_file(records_db, [{file, Recordfilename}, {type, set}]),
    Records = dets:lookup(records_db, RecordId1),
    ok = dets:close(records_db),
    Body = case Records of
        [{RecordId2, Data}] ->
            io_lib:format("id: \"~s\", record: \"~s\"",
                          [RecordId2, binary_to_list(Data)]);
        [] ->
            io_lib:format("{not_found: record ~p not found",
                          [RecordId1]);
        _ ->
            io_lib:format("{extra_records: extra records for ~p",
                          [RecordId1])
    end,
    {list_to_binary(Body), Req, State}.

create_record_to_json(Req, State) ->
    {ok, Body, Req1} = cowboy_req:read_urlencoded_body(Req),
	[{<<"content">>, Content}] = Body,
	io:format("Content: ~p~n",[Content]),
	RecordId = generate_id(),
    % RecordId = "2",
	io:format("Record id: ~p~n",[RecordId]),
    {ok, Recordfilename} = application:get_env(dance_club, records_file_name),
    {ok, _} = dets:open_file(records_db, [{file, Recordfilename}, {type, set}]),
	io:format("opened file, state db: ~p~n", [records_db]),
    ok = dets:insert(records_db, {RecordId, Content}),
	io:format("inserted: ~p~n",[Content]),
    ok = dets:sync(records_db),
    ok = dets:close(records_db),
	io:format("closed: ~p~n",[Content]),
    case cowboy_req:method(Req1) of
        <<"POST">> ->
			io:format("post and record id: ~p~n", [RecordId]),
            Response = io_lib:format("/get/~s", [RecordId]),
			io:format("responde: ~p~n",[Response]),
            {{true, list_to_binary(Response)}, Req1, State};
        _ ->
			io:format("no post: ~n"),
            {true, Req1, State}
    end.

delete_record_to_json(Req, State) ->
	io:format("delete: ~n"),
    case cowboy_req:method(Req) of
        <<"POST">> ->
            RecId = cowboy_req:binding(record_id, Req),
			io:format("recId: ~p~n", [RecId]),
            RecId1 = binary_to_list(RecId),
            {ok, Recordfilename} = application:get_env(
                dance_club, records_file_name),
            {ok, _} = dets:open_file(
                records_db, [{file, Recordfilename}, {type, set}]),
				io:format("opened file: ~p~n", [records_db]),
            DBResponse = dets:lookup(records_db, RecId1),
			io:format("DBResponse: ~p~n", [DBResponse]),
            Result = case DBResponse of
                [_] ->
					io:format("result: ~p~n", [before_delete]),
                    ok = dets:delete(records_db, RecId1),
                    ok = dets:sync(records_db),
                    Response = io_lib:format("/delete/~s", [RecId1]),
                    Response1 = list_to_binary(Response),
                    {{true, Response1}, Req, State};
                [] ->
                    {true, Req, State}
            end,
            ok = dets:close(records_db),
            Result;
        _ ->
            {true, Req, State}
    end.

update_record_to_json(Req, State) ->
    case cowboy_req:method(Req) of
        <<"POST">> ->
            RecId = cowboy_req:binding(record_id, Req),
            RecId1 = binary_to_list(RecId),
            {ok, Body, Req1} =
                cowboy_req:read_urlencoded_body(Req),
			io:format("update body ~p~n", [Body]),
			[{<<"content">>, NewContent}] = Body,
			io:format("update body ~p~n", [NewContent]),
            {ok, Recordfilename} = application:get_env(
                dance_club, records_file_name),
            {ok, _} = dets:open_file(
                records_db, [{file, Recordfilename}, {type, set}]),
            DBResponse = dets:lookup(records_db, RecId1),
            Result = case DBResponse of
                [_] ->
                    ok = dets:insert(records_db, {RecId1, NewContent}),
                    ok = dets:sync(records_db),
                    Response = io_lib:format("/get/~s", [RecId1]),
                    Response1 = list_to_binary(Response),
                    {{true, Response1}, Req1, State};
                [] ->
                    {true, Req1, State}
            end,
            ok = dets:close(records_db),
            Result;
        _ ->
            {true, Req, State}
    end.

delete_resource(Req, State) ->
    RecordId = cowboy_req:binding(record_id, Req),
    RecordId1 = binary_to_list(RecordId),
    {ok, Recordfilename} = application:get_env(dance_club, records_file_name),
    {ok, _} = dets:open_file(records_db, [{file, Recordfilename}, {type, set}]),
    Result = dets:delete(records_db, RecordId1),
    ok = dets:close(records_db),
    Response = case Result of
        ok ->
            true;
        {error, _Reason} ->
            false
    end,
    {Response, Req, State}.

resource_exists(Req, State) ->
    case cowboy_req:method(Req) of
        <<"DELETE">> ->
            RecordId = cowboy_req:binding(record_id, Req),
            RecordId1 = binary_to_list(RecordId),
            {ok, Recordfilename} = application:get_env(
                 dance_club, records_file_name),
            {ok, _} = dets:open_file(
                records_db, [{file, Recordfilename}, {type, set}]),
            Records = dets:lookup(records_db, RecordId1),
            ok = dets:close(records_db),
            Response = case Records of
                [_] ->
                    {true, Req, State};
                _ ->
                    {false, Req, State}
            end,
            Response;
        _ ->
            {true, Req, State}
    end.

generate_id() ->
	io:format("generate id~n"),
    {ok, Statefilename} = application:get_env(dance_club, state_file_name),
	io:format("Statefile name: ~p~n",[Statefilename]),
    dets:open_file(state_db, [{file, Statefilename}, {type, set}]),
	io:format("opened file, state db: ~p~n", [state_db]),
	io:format("lookup: ~p~n",[dets:first(state_db)]),
    Records = dets:lookup(state_db, current_id),
	io:format("Records in id: ~p~n",[Records]),
    Response = case Records of
        [{current_id, CurrentId}] ->
            NextId = CurrentId + 1,
            %    CurrentId, NextId]),
            dets:insert(state_db, {current_id, NextId}),
            Id = lists:flatten(io_lib:format("id_~4..0B", [CurrentId])),
            Id;
        [] ->
            error
    end,
    dets:close(state_db),
    Response.