/**
 *  Copyright 2007-2011 Zuse Institute Berlin
 *
 *   Licensed under the Apache License, Version 2.0 (the "License");
 *   you may not use this file except in compliance with the License.
 *   You may obtain a copy of the License at
 *
 *       http://www.apache.org/licenses/LICENSE-2.0
 *
 *   Unless required by applicable law or agreed to in writing, software
 *   distributed under the License is distributed on an "AS IS" BASIS,
 *   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *   See the License for the specific language governing permissions and
 *   limitations under the License.
 */
package de.zib.scalaris.examples;

import java.util.HashSet;
import java.util.List;
import java.util.Set;

import com.ericsson.otp.erlang.OtpErlangBinary;
import com.ericsson.otp.erlang.OtpErlangString;

import de.zib.scalaris.Benchmark;
import de.zib.scalaris.ConnectionFactory;
import de.zib.scalaris.PeerNode;
import de.zib.scalaris.RoundRobinConnectionPolicy;

/**
 * Mini benchmark of the {@link de.zib.scalaris.Transaction} and
 * {@link de.zib.scalaris.TransactionSingleOp} class using custom objects
 * provided by {@link ErlangValueFastString} and {@link ErlangValueBitString}.
 *
 * <p>
 * Run the benchmark with
 * <code>java -cp scalaris-examples.jar de.zib.scalaris.examples.FastStringBenchmark</code>
 * </p>
 *
 * @author Nico Kruber, kruber@zib.de
 * @version 3.0
 * @since 2.0
 */
public class FastStringBenchmark extends Benchmark {
    /**
     * Runs a mini benchmark of the {@link de.zib.scalaris.Transaction} and
     * {@link de.zib.scalaris.TransactionSingleOp} class using custom objects
     * provided by {@link ErlangValueFastString} and
     * {@link ErlangValueBitString}. Accepts the same parameters as the
     * {@link de.zib.scalaris.Main#main(String[])} method's benchmark parameter.
     *
     * @param args
     *            command line arguments
     *
     * @see de.zib.scalaris.Main#main(String[])
     */
    public static void main(final String[] args) {
        int testruns = 100;
        final HashSet<Integer> benchmarks = new HashSet<Integer>(10);
        if ((args != null) && (args.length >= 2)) {
            testruns = Integer.parseInt(args[0]);
            for (int i = 1; i < Math.min(10, args.length); ++i) {
                final String benchmarks_str = args[i];
                if (benchmarks_str.equals("all")) {
                    for (int j = 1; j <= 9; ++j) {
                        benchmarks.add(j);
                    }
                } else {
                    benchmarks.add(Integer.parseInt(benchmarks_str));
                }
            }
        } else {
            for (int i = 1; i <= 9; ++i) {
                benchmarks.add(i);
            }
        }
        minibench(testruns, benchmarks);
    }

    /**
     * Runs the benchmark.
     *
     * Tests some strategies for writing key/value pairs to scalaris:
     * <ol>
     *  <li>writing {@link OtpErlangBinary} objects (random data, size = {@link #BENCH_DATA_SIZE})</li>
     *  <li>writing {@link OtpErlangString} objects (random data, size = {@link #BENCH_DATA_SIZE})</li>
     *  <li>writing {@link String} objects (random data, size = {@link #BENCH_DATA_SIZE})</li>
     *  <li>writing {@link String} objects by converting them to {@link OtpErlangBinary}s
     *      (random data, size = {@link #BENCH_DATA_SIZE})</li>
     * </ol>
     * each testruns times
     * <ul>
     *  <li>first using a new {@link de.zib.scalaris.Transaction} for each test,</li>
     *  <li>then using a new {@link de.zib.scalaris.Transaction} but re-using a single {@link de.zib.scalaris.Connection},</li>
     *  <li>and finally re-using a single {@link de.zib.scalaris.Transaction} object.</li>
     * </ul>
     *
     * @param testruns
     *            the number of test runs to execute
     * @param benchmarks
     *            the benchmarks to run (1-9 or -1 for all benchmarks)
     */
    public static void minibench(final int testruns, final Set<Integer> benchmarks) {
        ConnectionFactory cf = ConnectionFactory.getInstance();
        List<PeerNode> nodes = cf.getNodes();
        parallelRuns = nodes.size();
        // set a connection policy that goes through the available nodes in a round-robin fashion:
        cf.setConnectionPolicy(new RoundRobinConnectionPolicy(nodes));
        System.out.println("Number of available nodes: " + nodes.size());
        System.out.println("-> Using " + parallelRuns + " parallel instances per test run...");
        long[][] results;
        String[] columns;
        String[] rows;
        @SuppressWarnings("rawtypes")
        Class[] testTypes;
        String[] testTypesStr;
        @SuppressWarnings("rawtypes")
        Class[] testBench;
        String testGroup;

        System.out.println("Benchmark of de.zib.scalaris.TransactionSingleOp:");
        results = getResultArray(3, 3);
        testTypes = new Class[] {String.class, ErlangValueBitString.class, ErlangValueFastString.class};
        testTypesStr = new String[] {"S", "EVBS", "EVFS"};
        columns = new String[] {
                "TransactionSingleOp.write(String, String)",
                "TransactionSingleOp.write(String, ErlangValueBitString)",
                "TransactionSingleOp.write(String, ErlangValueFastString)" };
        testBench = new Class[] {Benchmark.TransSingleOpBench1.class, Benchmark.TransSingleOpBench2.class, Benchmark.TransSingleOpBench3.class};
        rows = new String[] {
                "separate connection",
                "re-use connection",
                "re-use object" };
        testGroup = "transsinglebench";
        runBenchAndPrintResults(testruns, benchmarks, results, columns, rows,
                testTypes, testTypesStr, testBench, testGroup, 1);

        System.out.println("-----");
        System.out.println("Benchmark of de.zib.scalaris.Transaction:");
        results = getResultArray(3, 3);
        testTypes = new Class[] {String.class, ErlangValueBitString.class, ErlangValueFastString.class};
        testTypesStr = new String[] {"S", "EVBS", "EVFS"};
        columns = new String[] {
                "Transaction.write(String, String)",
                "Transaction.write(String, ErlangValueBitString)",
                "Transaction.write(String, ErlangValueFastString)" };
        testBench = new Class[] {Benchmark.TransBench1.class, Benchmark.TransBench2.class, Benchmark.TransBench3.class};
        rows = new String[] {
                "separate connection",
                "re-use connection",
                "re-use object" };
        testGroup = "transsinglebench";
        runBenchAndPrintResults(testruns, benchmarks, results, columns, rows,
                testTypes, testTypesStr, testBench, testGroup, 1);
    }
}
