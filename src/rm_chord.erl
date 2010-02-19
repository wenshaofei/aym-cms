%  Copyright 2007-2009 Konrad-Zuse-Zentrum fuer Informationstechnik Berlin
%
%   Licensed under the Apache License, Version 2.0 (the "License");
%   you may not use this file except in compliance with the License.
%   You may obtain a copy of the License at
%
%       http://www.apache.org/licenses/LICENSE-2.0
%
%   Unless required by applicable law or agreed to in writing, software
%   distributed under the License is distributed on an "AS IS" BASIS,
%   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%   See the License for the specific language governing permissions and
%   limitations under the License.
%%%-------------------------------------------------------------------
%%% File    : rm_chord.erl
%%% Author  : Thorsten Schuett <schuett@zib.de>
%%% Description : Chord-like ring maintenance
%%%
%%% Created :  27 Nov 2008 by Thorsten Schuett <schuett@zib.de>
%%%-------------------------------------------------------------------
%% @author Thorsten Schuett <schuett@zib.de>
%% @copyright 2007-2008 Konrad-Zuse-Zentrum fuer Informationstechnik Berlin
%% @version $Id$
-module(rm_chord).

-author('schuett@zib.de').
-vsn('$Id$ ').



-behavior(ring_maintenance).
-behavior(gen_component).

-export([init/1,on/2]).

-export([start_link/1, 
	 get_successorlist/1, succ_left/1, pred_left/1, 
	 notify/1, update_succ/1, update_pred/1, 
	 get_predlist/0]).

% unit testing
-export([merge/3]).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Public Interface
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% @doc spawns a chord-like ring maintenance process
%% @spec start_link(term()) -> {ok, pid()}
start_link(InstanceId) ->
    start_link(InstanceId, []).

start_link(InstanceId,Options) ->
   gen_component:start_link(?MODULE, [InstanceId, Options], [{register, InstanceId, ring_maintenance}]).




%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Startup
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% @doc starts ring maintenance

init(_Args) ->
    log:log(info,"[ RM ~p ] starting ring maintainer~n", [self()]),
    cs_send:send_local(get_cs_pid(), {init_rm,self()}),
    cs_send:send_after(config:stabilizationInterval(), self(), {stabilize}),
    uninit.
    

get_successorlist(Source) ->
    cs_send:send_local(get_pid() , {get_successorlist,Source,Source}).
    

%% @doc notification that my succ left
%%      parameter is his current succ list
succ_left(_Succ) ->
    %% @TODO
    ok.

%% @doc notification that my pred left
%%      parameter is his current pred
pred_left(_PredsPred) ->
    %% @TODO
    ok.

%% @doc notification that my succ changed
%%      parameter is potential new succ
update_succ(_Succ) ->
    %% @TODO
    ok.

%% @doc notification that my pred changed
%%      parameter is potential new pred
update_pred(_Pred) ->
    %% @TODO
    ok.

notify(Pred) ->
    cs_send:send_local(get_pid() , {notify, Pred}).



get_predlist() ->
    log:log(error, "[ RM-CHORD] OLD FUNCTION use broke with gen_component"),
    cs_send:send_local(get_pid() , {get_predlist, self()}),
    receive
	{get_predlist_response, PredList} ->
	    PredList
    end.
    
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Internal Loop
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%set info for cs_node
on({init, NewId, NewMe, NewPred, NewSuccList, _CSNode},uninit) ->
        ring_maintenance:update_succ_and_pred(NewPred, hd(NewSuccList)),
        cs_send:send(node:pidX(hd(NewSuccList)), {get_succ_list, cs_send:this()}),
        fd:subscribe([node:pidX(Node) || Node <- [NewPred | NewSuccList]]),
       
        {NewId, NewMe, NewPred, NewSuccList};
on(_,uninit) ->
        uninit;
on({get_successorlist, Pid},{Id, Me, Pred, Succs})  ->
	    cs_send:send_local(Pid , {get_successorlist_response, Succs}),
	    {Id, Me, Pred, Succs};
on({get_successorlist, Pid,S},{Id, Me, Pred, Succs})  ->
        cs_send:send_local(Pid , {get_successorlist_response, Succs,S}),
        {Id, Me, Pred, Succs};
on({get_predlist, Pid},{Id, Me, Pred, Succs})  ->
        cs_send:send_local(Pid , {get_predlist_response, [Pred]}),
       	{Id, Me, Pred, Succs};

on({stabilize},{Id, Me, Pred, Succs})  -> % new stabilization interval
        case Succs of
            [] -> 
                ok;
            _  -> 
                cs_send:send(node:pidX(hd(Succs)), {get_pred, cs_send:this()})
        end,
        cs_send:send_after(config:stabilizationInterval(), self(), {stabilize}),
	    {Id, Me, Pred, Succs};
on({get_pred_response, SuccsPred},{Id, Me, Pred, Succs})  ->
	    case node:is_null(SuccsPred) of
		false ->
		    case util:is_between_stab(Id, node:id(SuccsPred), node:id(hd(Succs))) of
			true ->
			    cs_send:send(node:pidX(SuccsPred), {get_succ_list, cs_send:this()}),
			    ring_maintenance:update_succ_and_pred(Pred, SuccsPred),
			    fd:subscribe(node:pidX(SuccsPred)),
			    {Id, Me, Pred, [SuccsPred | Succs]};
			false ->
			    cs_send:send(node:pidX(hd(Succs)), {get_succ_list, cs_send:this()}),
			    {Id, Me, Pred, Succs}
		    end;
		true ->
		    cs_send:send(node:pidX(hd(Succs)), {get_succ_list, cs_send:this()}),
		    {Id, Me, Pred, Succs}
	    end;
on({get_succ_list_response, Succ, SuccsSuccList},{Id, Me, Pred, Succs})  ->
	    NewSuccs = util:trunc(merge([Succ | SuccsSuccList], Succs, Id), config:succListLength()),
	    %% @TODO if(length(NewSuccs) < succListLength() / 2) do something right now
	    cs_send:send(node:pidX(hd(NewSuccs)), {notify, Me}),
	    ring_maintenance:update_succ_and_pred(Pred, hd(NewSuccs)), 
	    fd:subscribe([node:pidX(Node) || Node <- NewSuccs]),
	    {Id, Me, Pred, NewSuccs};
on({notify, NewPred},{Id, Me, Pred, Succs})  ->
	    case node:is_null(Pred) of
		true ->
		    ring_maintenance:update_succ_and_pred(NewPred, hd(Succs)),
		    fd:subscribe(node:pidX(NewPred)),
		    {Id, Me, NewPred, Succs};
		false ->
		    case util:is_between_stab(node:id(Pred), node:id(NewPred), Id) of
			true ->
			    ring_maintenance:update_succ_and_pred(NewPred, hd(Succs)),
			    fd:subscribe(node:pidX(NewPred)),
			    {Id, Me, NewPred, Succs};
			false ->
			    {Id, Me, Pred, Succs}
		    end
	    end;
on({crash, DeadPid},{Id, Me, Pred, Succs})  ->
	    case node:is_null(Pred) orelse DeadPid == node:pidX(Pred) of
		true ->
		    {Id, Me, node:null(), filter(DeadPid, Succs)};
		false ->
		    {Id, Me, Pred, filter(DeadPid, Succs)}
	    end;
on({'$gen_cast', {debug_info, Requestor}},{Id, Me, Pred, Succs})  ->
	    cs_send:send_local(Requestor , {debug_info_response, [{"pred", lists:flatten(io_lib:format("~p", [Pred]))},{"succs", lists:flatten(io_lib:format("~p", [Succs]))}]}),
	    {Id, Me, Pred, Succs};

on(_, _State) ->
    unknown_event.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Internal Functions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% @doc merge two successor lists into one
%%      and sort by identifier
merge(L1, L2, Id) ->
    MergedList = lists:append(L1, L2),
    Order = fun(A, B) ->
		    node:id(A) =< node:id(B)
	    end,
    Larger  = util:uniq(lists:sort(Order, [X || X <- MergedList, node:id(X) >  Id])),
    Equal   = util:uniq(lists:sort(Order, [X || X <- MergedList, node:id(X) == Id])),
    Smaller = util:uniq(lists:sort(Order, [X || X <- MergedList, node:id(X) <  Id])),
    lists:append([Larger, Smaller, Equal]).

filter(_Pid, []) ->
    [];
filter(Pid, [Succ | Rest]) ->
    case Pid == node:pidX(Succ) of
	true ->
	    filter(Pid, Rest);
	false ->
	    [Succ | filter(Pid, Rest)]
    end.



% @private
get_pid() ->
    process_dictionary:lookup_process(erlang:get(instance_id), ring_maintenance).

% get Pid of assigned cs_node
get_cs_pid() ->
    InstanceId = erlang:get(instance_id),
    if
	InstanceId == undefined ->
	   log:log(error,"[ RM | ~w ] ~p", [self(),util:get_stacktrace()]);
	true ->
	    ok
    end,
    process_dictionary:lookup_process(InstanceId, cs_node).
