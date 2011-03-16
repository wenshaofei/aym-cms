#!/usr/bin/python
# Copyright 2011 Zuse Institute Berlin
#
#    Licensed under the Apache License, Version 2.0 (the "License");
#    you may not use this file except in compliance with the License.
#    You may obtain a copy of the License at
#
#        http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS,
#    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#    See the License for the specific language governing permissions and
#    limitations under the License.

import Scalaris

def read_or_write(sc,  key,  value,  mode):
    if (mode == 'read'):
        print 'read(' + key + ')'
        print '  expected: ' + repr(value)
        res = sc.read(key)
        if (res['status'] == 'ok'):
            print '  read raw: ' + repr(res['value'])
            # if the expected value is a list, the returned value could by (mistakenly) a string if it is a list of integers
            # -> convert such a string to a list
            if (type(value).__name__=='list'):
                try:
                    actual = Scalaris.str_to_list(res['value'])
                except:
                    print 'fail'
                    return 1
            else:
                 actual = res['value']
            print '   read py: ' + repr(actual)
            if (actual == value):
                print 'ok'
                return 0
            else:
                print 'fail'
                return 1
        else:
            print 'read(' + key + ') failed with ' + res['reason']
            return 1
    elif (mode == 'write'):
        print 'write(' + key + ', ' + repr(value)+ ')'
        sc.write(key,  value)
        return 0

def read_write_integer(basekey, sc, mode):
    failed = 0;
    
    failed += read_or_write(sc,  basekey + "_int_0", 0,  mode)
    failed += read_or_write(sc,  basekey + "_int_1", 1,  mode)
    failed += read_or_write(sc,  basekey + "_int_min",  -2147483648,  mode)
    failed += read_or_write(sc,  basekey + "_int_max", 2147483647,  mode)
    failed += read_or_write(sc,  basekey + "_int_max_div_2", 2147483647 / 2,  mode)
    
    return failed

def read_write_long(basekey, sc, mode):
    failed = 0;
    
    failed += read_or_write(sc,  basekey + "_long_0", 0l,  mode)
    failed += read_or_write(sc,  basekey + "_long_1", 1l,  mode)
    failed += read_or_write(sc,  basekey + "_long_min",  -9223372036854775808l,  mode)
    failed += read_or_write(sc,  basekey + "_long_max", 9223372036854775807l,  mode)
    failed += read_or_write(sc,  basekey + "_long_max_div_2", 9223372036854775807l / 2l,  mode)
    
    return failed

def read_write_biginteger(basekey, sc, mode):
    failed = 0;
    
    failed += read_or_write(sc,  basekey + "_bigint_0", 0,  mode)
    failed += read_or_write(sc,  basekey + "_bigint_1", 1,  mode)
    failed += read_or_write(sc,  basekey + "_bigint_min",  -100000000000000000000,  mode)
    failed += read_or_write(sc,  basekey + "_bigint_max", 100000000000000000000,  mode)
    failed += read_or_write(sc,  basekey + "_bigint_max_div_2", 100000000000000000000 / 2,  mode)
    
    return failed

def read_write_double(basekey, sc, mode):
    failed = 0;
    
    failed += read_or_write(sc,  basekey + "_float_0.0", 0.0,  mode)
    failed += read_or_write(sc,  basekey + "_float_1.5", 1.5,   mode)
    failed += read_or_write(sc,  basekey + "_float_-1.5",  -1.5,  mode)
    failed += read_or_write(sc,  basekey + "_float_min", 4.9E-324,  mode)
    failed += read_or_write(sc,  basekey + "_float_max", 1.7976931348623157E308,  mode)
    failed += read_or_write(sc,  basekey + "_float_max_div_2", 1.7976931348623157E308 / 2,  mode)
    
    # not supported by erlang:
    #failed += read_or_write(sc,  basekey + "_float_neg_inf", float('-inf'),  mode)
    #failed += read_or_write(sc,  basekey + "__float_pos_inf", float('+inf'),  mode)
    #failed += read_or_write(sc,  basekey + "_float_nan", float('nan'),  mode)
    
    return failed

def read_write_string(basekey, sc, mode):
    failed = 0;
    
    failed += read_or_write(sc,  basekey + "_string_empty", '',  mode)
    failed += read_or_write(sc,  basekey + "_string_foobar", 'foobar',   mode)
    failed += read_or_write(sc,  basekey + "_string_foo\\nbar",  'foo\nbar',  mode)
    
    return failed

def read_write_binary(basekey, sc, mode):
    failed = 0;
    
    # note: binary not supported by JSON
    failed += read_or_write(sc,  basekey + "_byte_empty", bytearray(),  mode)
    failed += read_or_write(sc,  basekey + "_byte_0", bytearray([0]),   mode)
    failed += read_or_write(sc,  basekey + "_byte_0123",  bytearray([0,  1,  2,  3]),  mode)
    
    return failed

def read_write_list(basekey, sc, mode):
    failed = 0;
    
    failed += read_or_write(sc,  basekey + "_list_empty", [],  mode)
    failed += read_or_write(sc,  basekey + "_list_0_1_2_3", [0,  1,  2,  3],   mode)
    failed += read_or_write(sc,  basekey + "_list_0_123_456_65000", [0,  123,  456,  65000],   mode)
    failed += read_or_write(sc,  basekey + "_list_0_123_456_0x10ffff", [0,  123,  456,  0x10ffff],   mode)
    failed += read_or_write(sc,  basekey + "_list_0_foo_1.5",  [0,  'foo',  1.5],  mode)
    # note: binary not supported in lists
    #failed += read_or_write(sc,  basekey + "_list_0_foo_1.5_<<0123>>",  [0,  'foo',  1.5,  bytearray([0,  1,  2,  3])],  mode)
    
    return failed

def read_write_map(basekey, sc, mode):
    failed = 0;
    
    failed += read_or_write(sc,  basekey + "_map_empty", {},  mode)
    failed += read_or_write(sc,  basekey + "_map_x0_y1", {'x': 0,  'y': 1},   mode)
    failed += read_or_write(sc,  basekey + "_map_a0_bfoo_c1.5_dfoo<nl>bar_elist0123_fmapx0y1",
                            {'a': 0,  'b': 'foo',  'c': 1.5,  'd': 'foo\nbar',  'e': [0,  1,  2,  3],  'f': {'x': 0,  'y': 1}},  mode)
    
    return failed

if __name__ == "__main__":
    import sys
    if (sys.argv[1] == "read"):
        basekey = sys.argv[2]
        language = sys.argv[3]
        basekey += '_' + language
        mode = 'read'
    elif (sys.argv[1] == "write"):
        basekey = sys.argv[2]
        basekey += '_json_python'
        mode = 'write'
    else:
        print 'unknown commands: ' + str(sys.argv)
        sys.exit(1)
    
    sc = Scalaris.TransactionSingleOp()
    failed = 0
    failed += read_write_integer(basekey, sc,  mode)
    failed += read_write_long(basekey, sc,  mode)
    failed += read_write_biginteger(basekey, sc,  mode)
    failed += read_write_double(basekey, sc,  mode)
    failed += read_write_string(basekey, sc,  mode)
    failed += read_write_binary(basekey, sc,  mode)
    failed += read_write_list(basekey, sc,  mode)
    failed += read_write_map(basekey, sc,  mode)
    
    if (failed > 0):
        print str(failed) + ' number of ' + mode + 's failed.'
        sys.exit(1)