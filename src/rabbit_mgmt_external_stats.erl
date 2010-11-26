%%   The contents of this file are subject to the Mozilla Public License
%%   Version 1.1 (the "License"); you may not use this file except in
%%   compliance with the License. You may obtain a copy of the License at
%%   http://www.mozilla.org/MPL/
%%
%%   Software distributed under the License is distributed on an "AS IS"
%%   basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See the
%%   License for the specific language governing rights and limitations
%%   under the License.
%%
%%   The Original Code is RabbitMQ Management Console.
%%
%%   The Initial Developers of the Original Code are Rabbit Technologies Ltd.
%%
%%   Copyright (C) 2010 Rabbit Technologies Ltd.
%%
%%   All Rights Reserved.
%%
%%   Contributor(s): ______________________________________.
%%

-module(rabbit_mgmt_external_stats).

-behaviour(gen_server).

-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2,
         code_change/3]).

-export([info/1]).

-include_lib("rabbit_common/include/rabbit.hrl").

-define(REFRESH_RATIO, 5000).
-define(KEYS, [os_pid, mem_ets, mem_binary, sockets_used, sockets_total,
               mem_used, mem_limit, proc_used, proc_total, statistics_level,
               erlang_version, uptime, run_queue, processors]).

%%--------------------------------------------------------------------

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

info(Node) ->
    try
        gen_server2:call({?MODULE, Node}, {info, ?KEYS}, infinity)
    catch
        exit:{noproc, _} -> [{external_stats_not_running, true}]
    end.

%%--------------------------------------------------------------------

get_memory_limit() ->
    try
        vm_memory_monitor:get_memory_limit()
    catch exit:{noproc, _} -> memory_monitoring_disabled
    end.

%%--------------------------------------------------------------------

infos(Items, State) -> [{Item, i(Item, State)} || Item <- Items].

i(sockets_total,  _State) -> file_handle_cache:get_obtain_limit();
i(sockets_used,   _State) -> file_handle_cache:get_obtain_count();
i(os_pid,         _State) -> list_to_binary(os:getpid());
i(mem_ets,        _State) -> erlang:memory(ets);
i(mem_binary,     _State) -> erlang:memory(binary);
i(mem_used,       _State) -> erlang:memory(total);
i(mem_limit,      _State) -> get_memory_limit();
i(proc_used,      _State) -> erlang:system_info(process_count);
i(proc_total,     _State) -> erlang:system_info(process_limit);
i(erlang_version, _State) -> list_to_binary(erlang:system_info(otp_release));
i(run_queue,      _State) -> erlang:statistics(run_queue);
i(processors,     _State) -> erlang:system_info(logical_processors);
i(uptime, _State) ->
    {Total, _} = erlang:statistics(wall_clock),
    Total;
i(statistics_level, _State) ->
    {ok, StatsLevel} = application:get_env(rabbit, collect_statistics),
    StatsLevel.

%%--------------------------------------------------------------------

init([]) ->
    {ok, no_state}.

handle_call({info, Items}, _From, State) ->
    {reply, infos(Items, State), State};

handle_call(_Req, _From, State) ->
    {reply, unknown_request, State}.

handle_cast(_C, State) ->
    {noreply, State}.


handle_info(_I, State) ->
    {noreply, State}.

terminate(_, _) -> ok.

code_change(_, State, _) -> {ok, State}.

