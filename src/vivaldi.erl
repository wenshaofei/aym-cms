%  Copyright 2007-2008 Konrad-Zuse-Zentrum fuer Informationstechnik Berlin
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
%%% File    : vivaldi.erl
%%% Author  : Thorsten Schuett <schuett@zib.de>
%%% Description : vivaldi is a network coordinate system
%%%
%%% Created :  8 July 2009 by Thorsten Schuett <schuett@zib.de>
%%%-------------------------------------------------------------------
%% @author Thorsten Schuett <schuett@zib.de>
%% @copyright 2009 Konrad-Zuse-Zentrum fuer Informationstechnik Berlin
%% @version $Id$
%% @reference Frank Dabek, Russ Cox, Frans Kaahoek, Robert Morris. <em>
%% Vivaldi: A Decentralized Network Coordinate System</em>. SigComm 2004.
%% @reference Jonathan Ledlie, Peter Pietzuch, Margo Seltzer. <em>Stable
%% and Accurate Network Coordinates</em>. ICDCS 2006.
-module(vivaldi,[Trigger]).

-author('schuett@zib.de').
-vsn('$Id$ ').

-behaviour(gen_component).

-export([start_link/1]).

-export([on/2, init/1,get_base_interval/0]).

% vivaldi types
-type(network_coordinate() :: [float()]).
-type(error() :: float()).
-type(latency() :: number()).

% state of the vivaldi loop
-type(state() :: {network_coordinate(), error()}).

% accepted messages of vivaldi processes
-type(message() :: any()).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Message Loop
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% start new vivaldi shuffle
%% @doc message handler
-spec(on/2 :: (Message::message(), State::state()) -> state()).
on({trigger},{Coordinate, Confidence,TriggerState} ) ->
    %io:format("{start_vivaldi_shuffle}: ~p~n", [get_local_cyclon_pid()]),
    NewTriggerState = Trigger:trigger_next(TriggerState,1),
    cyclon:get_subset_rand(1),
    {Coordinate, Confidence, NewTriggerState};

on({cy_cache, []}, State)  ->
    % ignore empty cache from cyclon
    State;

% got random node from cyclon
on({cy_cache, [Node] = _Cache}, {Coordinate, Confidence, _TriggerState} = State) ->
    %io:format("~p~n",[_Cache]),
    cs_send:send_to_group_member(node:pidX(Node), vivaldi,
                                 {vivaldi_shuffle, cs_send:this(),
                                  Coordinate, Confidence}),
    State;

%
on({vivaldi_shuffle, RemoteNode, RemoteCoordinate, RemoteConfidence},
   {Coordinate, Confidence, _TriggerState} = State) ->
    %io:format("{shuffle, ~p, ~p}~n", [RemoteCoordinate, RemoteConfidence]),
    cs_send:send(RemoteNode, {vivaldi_shuffle_reply, cs_send:this(),
                              Coordinate, Confidence}),
    vivaldi_latency:measure_latency(RemoteNode, RemoteCoordinate, RemoteConfidence),
    State;

on({vivaldi_shuffle_reply, _RemoteNode, _RemoteCoordinate, _RemoteConfidence}, State) ->
    %io:format("{shuffle_reply, ~p, ~p}~n", [RemoteCoordinate, RemoteConfidence]),
    %vivaldi_latency:measure_latency(RemoteNode, RemoteCoordinate, RemoteConfidence),
    State;

on({update_vivaldi_coordinate, Latency, {RemoteCoordinate, RemoteConfidence}},
   {Coordinate, Confidence,TriggerState}) ->
    %io:format("latency is ~pus~n", [Latency]),
    {NewCoordinate, NewConfidence } =
        try
            update_coordinate(RemoteCoordinate, RemoteConfidence,
                              Latency, Coordinate, Confidence)
        catch
            % ignore any exceptions, e.g. badarith
            error:_ -> {Coordinate, Confidence }
        end,
    {NewCoordinate, NewConfidence, TriggerState};

on({query_vivaldi, Pid}, {Coordinate, Confidence, _TriggerState} = State) ->
    cs_send:send(Pid,{query_vivaldi_response,Coordinate,Confidence}),
    State;

on(_, _State) ->
    unknown_event.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Init
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
-spec(init/1 :: ([any()]) -> vivaldi:state()).
init([_InstanceId, []]) ->
    %io:format("vivaldi start ~n"),
    TriggerState = Trigger:init(THIS),
    TriggerState2 = Trigger:trigger_first(TriggerState,1),
    {random_coordinate(), 1.0,TriggerState2}.

%% @spec start_link(term()) -> {ok, pid()}
start_link(InstanceId) ->
    gen_component:start_link(THIS, [InstanceId, []], [{register, InstanceId, vivaldi}]).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Helpers
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

-spec(random_coordinate/0 :: () -> network_coordinate()).
random_coordinate() ->
    Dim = config:read(vivaldi_dimensions, 2),
    % note: network coordinates are float vectors!
    [ float(crypto:rand_uniform(1, 10)) || _ <- lists:seq(1, Dim) ].

-spec(update_coordinate/5 :: (network_coordinate(), error(), latency(),
                              network_coordinate(), error()) -> vivaldi:state()).
update_coordinate(Coordinate, _RemoteError, _Latency, Coordinate, Error) ->
    % same coordinate
    {Coordinate, Error};
update_coordinate(RemoteCoordinate, RemoteError, Latency, Coordinate, Error) ->
    Cc = 0.5, Ce = 0.5,
    % sample weight balances local and remote error
    W = Error/(Error + RemoteError),
    % relative error of sample
    Es = abs(mathlib:euclideanDistance(RemoteCoordinate, Coordinate) - Latency) / Latency,
    % update weighted moving average of local error
    Error1 = Es * Ce * W + Error * (1 - Ce * W),
    % update local coordinates
    Delta = Cc * W,
    %io:format('expected latency: ~p~n', [mathlib:euclideanDist(Coordinate, _RemoteCoordinate)]),
    C1 = mathlib:u(mathlib:vecSub(Coordinate, RemoteCoordinate)),
    C2 = mathlib:euclideanDistance(Coordinate, RemoteCoordinate),
    C3 = Latency - C2,
    C4 = C3 * Delta,
    Coordinate1 = mathlib:vecAdd(Coordinate, mathlib:vecMult(C1, C4)),
    %io:format("new coordinate ~p and error ~p~n", [Coordinate1, Error1]),
    {Coordinate1, Error1}.

get_base_interval() ->
    config:read(vivaldi_interval).
