% @copyright 2010-2011 Zuse Institute Berlin

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

%%% @author Nico Kruber <kruber@zib.de>
%%% @doc    Unit tests for src/db_ets.erl.
%%% @end
%% @version $Id$
-module(db_ets_SUITE).

-author('kruber@zib.de').
-vsn('$Id$').

-compile(export_all).

-define(TEST_DB, db_ets).

-include("db_SUITE.hrl").

all() -> lists:append(tests_avail(), [tester_get_chunk_precond]).

%% @doc Specify how often a read/write suite can be executed in order not to
%%      hit a timeout (depending on the speed of the DB implementation).
-spec max_rw_tests_per_suite() -> pos_integer().
max_rw_tests_per_suite() ->
    10000.

tester_get_chunk_precond(_Config) ->
    Table = ets:new(ets_test_SUITE, [ordered_set | ?DB_ETS_ADDITIONAL_OPS]),
    ets:insert(Table, {5}),
    ets:insert(Table, {6}),
    ets:insert(Table, {7}),
    ?equals(ets:next(Table, 7), '$end_of_table'),
    ?equals(ets:next(Table, 6), 7),
    ?equals(ets:next(Table, 5), 6),
    ?equals(ets:next(Table, 4), 5),
    ?equals(ets:next(Table, 3), 5),
    ?equals(ets:next(Table, 2), 5),
    ?equals(ets:first(Table), 5).
