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
%%% File    : scalaris_app.erl
%%% Author  : Thorsten Schuett <schuett@zib.de>
%%% Description : scalaris application file
%%%
%%% Created :  3 May 2007 by Thorsten Schuett <schuett@zib.de>
%%%-------------------------------------------------------------------
%% @author Thorsten Schuett <schuett@zib.de>
%% @copyright 2007-2008 Konrad-Zuse-Zentrum fuer Informationstechnik Berlin
%% @version $Id$
-module(scalaris_app).

-author('schuett@zib.de').
-vsn('$Id$ ').

-behaviour(application).

-export([start/2, stop/1]).

-spec start(normal, NodeType::sup_scalaris:supervisor_type()) ->
                 {ok, Pid::pid()}
               | ignore
               | {error, Error::{already_started,
                                 Pid::pid()}
               | term()};
           (any(), any()) -> {error, badarg}.
start(normal, NodeType) ->
    process_dictionary:start_link(),
    Sup = sup_scalaris:start_link(NodeType),
    Size = config:read(nodes_per_vm),
    log:log(info,"Do ~p~n",[Size]),
    admin:add_nodes(Size-1),
    Sup;
start(_, _) ->
    {error, badarg}.

-spec stop(any()) -> ok.
stop(_State) ->
    ok.