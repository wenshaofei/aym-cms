%  @copyright 2007-2010 Konrad-Zuse-Zentrum fuer Informationstechnik Berlin

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

%% @author Thorsten Schuett <schuett@zib.de>
%% @version $Id$
-module(group_ops_remove_node).
-author('schuett@zib.de').
-vsn('$Id$').

-include("scalaris.hrl").
-include("group.hrl").

-export([ops_request/2, ops_decision/4, rejected_proposal/3]).

-type(proposal_type()::{group_node_remove, Pid::comm:mypid()}).

% @doc we got a request to remove a node from this group, do sanity checks and propose the removal
-spec ops_request(State::joined_state(),
                  Proposal::proposal_type()) -> joined_state().
ops_request({joined, NodeState, GroupState, TriggerState} = State,
            {group_node_remove, Pid} = _Proposal) ->
    case group_state:is_member(GroupState, Pid) of
        false ->
            comm:send(Pid, {group_node_remove_response,
                            Pid, is_no_member}),
            State;
        true ->
            case group_paxos_utils:propose({group_node_remove, Pid}, GroupState) of
                {success, NewGroupState} ->
                    {joined, NodeState, NewGroupState, TriggerState};
                _ ->
                    comm:send(Pid, {group_node_remove_response, retry}),
                    State
            end
    end.


% @doc it was decided to remove a node from our group: execute the removal
-spec ops_decision(State::joined_state(),
                   Proposal::proposal_type(),
                   PaxosId::any(),
                   Hint::decision_hint()) -> joined_state().
ops_decision({joined, NodeState, GroupState, TriggerState} = _State,
             {group_node_remove, Pid} = Proposal,
             PaxosId, _Hint) ->
    NewGroupState = group_state:remove_node(
                      group_state:remove_proposal(GroupState,
                                                  PaxosId),
                      Pid),
    group_utils:notify_neighbors(NodeState, GroupState,
                                 NewGroupState),
    % notify dead node
    Pred = group_local_state:get_predecessor(NodeState),
    Succ = group_local_state:get_successor(NodeState),
    comm:send(Pid, {group_state, NewGroupState, Pred, Succ}),
    fd:unsubscribe(Pid),
    {joined, NodeState, NewGroupState, TriggerState}.

-spec rejected_proposal(joined_state(), proposal_type(), paxos_id()) ->
    joined_state().
rejected_proposal(State,
                  {group_node_remove, Pid},
                  _PaxosId) ->
    comm:send(Pid, {group_node_remove_response, retry, Pid}),
    State.