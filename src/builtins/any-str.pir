## $Id$

=head1 NAME

src/builtins/any-str.pir -  C<Str>-like functions and methods for C<Any>

=head1 DESCRIPTION

This file implements the methods and functions of C<Any> that
are most closely associated with the C<Str> class or role.
We place them here instead of F<src/classes/Any.pir> to keep
the size of that file down and to emphasize their generic,
"built-in" nature.

=head2 Methods

=over 4

=cut

.include 'cclass.pasm'

.namespace []
.sub 'onload' :anon :init :load
    $P0 = get_hll_namespace ['Any']
    '!EXPORT'('chomp,chars,:d,:e,:f,index,rindex,substr', 'from'=>$P0)
.end


=item chars()

=cut

.namespace ['Any']

.sub 'chars' :method :multi(_)
    $S0 = self
    $I0 = length $S0
    .return ($I0)
.end

=item chomp

 our Str method Str::chomp ( Str $string: )

 Returns string with newline removed from the end.  An arbitrary
 terminator can be removed if the input filehandle has marked the
 string for where the "newline" begins.  (Presumably this is stored
 as a property of the string.)  Otherwise a standard newline is removed.

=cut

.sub 'chomp' :method :multi(_)
    .local string tmps
    .local string lastchar
    .local pmc retv

    tmps = self
    lastchar = substr tmps,-1
    if lastchar != "\n" goto done
    chopn tmps, 1
    lastchar = substr tmps,-1
    if lastchar != "\r" goto done
    chopn tmps, 1
  done:
       retv = new ['Str']
       retv = tmps
       .return (retv)
.end

=item ':d'()

 our Bool multi Str::':d' ( Str $filename )

Returns whether the file with the name indicated by the invocant is a
directory.

=cut

.sub ':d' :method :multi(_)
    .param int arg              :optional
    .param int has_arg          :opt_flag

    .local string filename
    filename = self

    push_eh not_a_dir
    $I0 = stat filename, 2
    if $I0 goto file_is_a_dir
  not_a_dir:
    $P0 = get_hll_global ['Bool'], 'False'
    .return ($P0)
  file_is_a_dir:
    $P0 = get_hll_global ['Bool'], 'True'
    .return ($P0)
.end

=item ':e'()

 our Bool multi Str::':e' ( Str $filename )

Returns whether the file with the name indicated by the invocant exists.

=cut

.sub ':e' :method :multi(_)
    .param int arg              :optional
    .param int has_arg          :opt_flag

    .local string filename
    filename = self

    $I0 = stat filename, 0
    if $I0 goto file_exists
    $P0 = get_hll_global ['Bool'], 'False'
    .return ($P0)
  file_exists:
    $P0 = get_hll_global ['Bool'], 'True'
    .return ($P0)
.end

=item ':f'()

 our Bool multi Str::':f' ( Str $filename )

Returns whether the file with the name indicated by the invocant is a plain
file.

=cut

.sub ':f' :method :multi(_)
    .param int arg              :optional
    .param int has_arg          :opt_flag

    .local string filename
    filename = self

    push_eh file_isnt_plain
    $I0 = stat filename, 2
    if $I0 goto file_isnt_plain
    $P0 = get_hll_global ['Bool'], 'True'
    .return ($P0)
  file_isnt_plain:
    $P0 = get_hll_global ['Bool'], 'False'
    .return ($P0)
.end

=item index()

=cut

.namespace ['Any']
.sub 'index' :method :multi(_)
    .param string substring
    .param int pos             :optional
    .param int has_pos         :opt_flag
    .local pmc retv

    if has_pos goto have_pos
    pos = 0
  have_pos:

    .local string s
    s = self

  check_substring:
    $I1 = length substring
    if $I1 goto substring_search
    $I0 = length s
    if pos < $I0 goto done
    pos = $I0
    goto done

  substring_search:
    pos = index s, substring, pos
    if pos < 0 goto notfound

  done:
    $P0 = new ['Int']
    $P0 = pos
    .return ($P0)

  fail:
    .tailcall '!FAIL'("Attempt to index from negative position")
  notfound:
    .tailcall '!FAIL'("Substring '", substring, "' not found in '", s, "'")
.end

=item match()

=cut

.sub 'match' :method :multi(_)
    .param pmc x
    .local pmc match
    match = x.'!invoke'(self)
    .return(match)
.end

=item rindex()

=cut

.namespace ['Any']
.sub 'rindex' :method :multi(_, _)
    .param string substring
    .param int pos             :optional
    .param int has_pos         :opt_flag
    .local pmc retv

  check_substring:
    if substring goto substring_search

    # we do not have substring return pos or length

    .local string s
    s = self
    $I0 = length s

    if has_pos goto have_pos
    pos = $I0
    goto done
  have_pos:
    if pos < $I0 goto done
    pos = $I0
    goto done

  substring_search:
    $I0 = self.'isa'('String')
    if $I0 goto self_string
    $P0 = root_new ['parrot';'String']
    $S0 = self
    $P0 = $S0
    goto do_search
  self_string:
    $P0 = self
  do_search:
    pos = $P0.'reverse_index'(substring, pos)
    if pos < 0 goto notfound

  done:
    $P0 = new ['Int']
    $P0 = pos
    .return ($P0)

  fail:
    .tailcall '!FAIL'("Attempt to index from negative position")
  notfound:
    .tailcall '!FAIL'("Substring '", substring, "' not found in '", s, "'")
.end

=item substr()

=cut

.namespace ['Any']
.sub 'substr' :method :multi(_, _)
    .param int start
    .param int len             :optional
    .param int has_len         :opt_flag

    if has_len goto have_len
    len = self.'chars'()
  have_len:
    if len >= 0 goto len_done
    if start < 0 goto neg_start
    $I0 = self.'chars'()
    len += $I0
  neg_start:
    len -= start
  len_done:
    $S0 = self
    push_eh fail
    $S1 = substr $S0, start, len
    pop_eh
    .return ($S1)
  fail:
    .get_results($P0)
    pop_eh
    .tailcall '!FAIL'($P0)
.end

=item trans()

  Implementation of transliteration

=cut

.sub '!transtable' :multi(_)
    .param pmc r
    .local pmc retval, tmps
    retval = root_new ['parrot';'ResizablePMCArray']
    tmps = clone r
  range_loop:
    unless tmps, done
    $P0 = tmps.'shift'()
    push retval, $P0
    goto range_loop
  done:
    .return(retval)
.end

# Handles Regexes and Closures

.sub '!transtable' :multi('Sub')
    .param pmc r
    .local pmc retval
    retval = root_new ['parrot';'ResizablePMCArray']
    push retval, r
    .return(retval)
.end

.sub '!transtable' :multi('String')
    .param string str
    .local pmc retval, prior, frm, to, next_str
    .local int start, end, len, ind, skipped, r_start, r_end, s_len
    .local string p
    retval = root_new ['parrot';'ResizablePMCArray']
    prior = root_new ['parrot';'ResizablePMCArray']
    start = 0
    skipped = 0
    len = length str
    end = len - 2
  next_index:
    ind = index str, '..' , start
    if ind == -1 goto last_string
    # ranges can only be after first position, before last one
    if ind == 0 goto skip_pos
    if ind >= end goto last_string
  init_range:
    r_start = ind - 1
    r_end = ind + 2
  range_frm:
    $S0 = substr str, r_start, 1
    $I0 = ord $S0
  range_to:
    $S1 = substr str, r_end, 1
    $I1 = ord $S1
  prev_string:
    s_len = r_start - start
    s_len += skipped
    unless s_len, start_range
    p = substr str, start, s_len
    prior = split '', p
  process_pstring:
    unless prior, start_range
    $S2 = shift prior
    next_str = new ['Str']
    next_str = $S2
    push retval, next_str
    goto process_pstring
  start_range:
    if $I0 > $I1 goto illegal_range
  make_range:
    # Here we're assuming the ordinal increments correctly for all chars.
    # This is a bit naive for now, it definitely needs some unicode testing.
    # If needed we can switch this over to use a true string Range
    if $I0 > $I1 goto next_loop
    $S2 = chr $I0
    next_str = new ['Str']
    next_str = $S2
    push retval, next_str
    inc $I0
    goto make_range
  illegal_range:
    die "Illegal range used in transliteration operator"
  next_loop:
    start = r_end + 1
    goto next_index
  skip_pos:
    inc start
    inc skipped
    goto next_index
  last_string:
    s_len = len - start
    if s_len <= 0 goto check_rval
    p = substr str, start, s_len
    prior = split '', p
  process_lstring:
    unless prior, check_rval
    $S0 = shift prior
    next_str = new ['Str']
    next_str = $S0
    push retval, next_str
    goto process_lstring
  check_rval:
    $I0 = elements retval
    if $I0 > 0 goto done
    push retval, ''
  done:
    .return(retval)
.end


.sub 'trans' :method
    .param pmc args :slurpy
    .param pmc adverbs         :slurpy :named
    .local int del, comp, squash
    $I0 = exists adverbs['d']
    $I1 = exists adverbs['delete']
    del = $I0 || $I1
    $I0 = exists adverbs['c']
    $I1 = exists adverbs['complement']
    comp = $I0 || $I1
    $I0 = exists adverbs['s']
    $I1 = exists adverbs['squash']
    squash = $I0 || $I1
    # TODO: unspec'd behavior: above arguments are similar
    # to p5 tr/// but are not described in S05, need some
    # clarification on whether these are implemented correctly
    .local pmc table, itable, retv, comp_match, by
    .local int len, klen, vlen, adjpos, pos, ind, nhits
    by = get_hll_global 'infix:<=>'
    # itable maps matching positions to key, value array
    itable = new ['Perl6Hash']
    retv = new ['Str']

  init_pair_loop:
    .local pmc pair, pkey, pval, pairlist
    .local int isatype
  pair_loop:
    unless args, init_trans
    pair = shift args
    # following is a cludge to get around list context issues
    # should be removed once that works
    isatype = isa pair, 'Perl6Pair'
    if isatype goto isa_pair
    isatype = isa pair, 'Hash'
    if isatype goto isa_hash
    isatype = isa pair, 'List'
    if isatype goto isa_list
    # change to Failure?
    die "Must pass a List of Pairs for transliteration"
  isa_hash:
    pairlist = pair.'pairs'()
    goto pairlist_loop
  isa_list:
    pairlist = clone pair
  pairlist_loop:
    unless pairlist, pair_loop
    pair = shift pairlist
    push args, pair
    goto pairlist_loop
  isa_pair:
    pkey = pair.'key'()
    pval = pair.'value'()
    pkey = '!transtable'(pkey)
    pval = '!transtable'(pval)
    vlen = elements pval
    if vlen goto comp_check
    if del goto comp_check
    pval = clone pkey
  comp_check:
    # for :c, I am using first element for replacing for now.  I can't find
    # any reliable examples where this is used otherwise
    comp_match = pval[0]

  init_mapping:
    .local pmc key, val, lastval, prev_val, prev_key
    .local string tmps
    .local int prev_pos, k_isa_regex
    tmps = self
  mapping:
    .local pmc match, km
    unless pkey, pair_loop
    key = shift pkey
    unless pval, get_prev1
    lastval = shift pval
  get_prev1:
    if del, get_prev2
    val = lastval
    goto init_index_loop
  get_prev2:
    val = new ['Str']
    val = ''
  init_index_loop:
    nhits = 0
    pos = 0
    prev_pos = 0
    # assume key is always a Str for now (will need to adjust for Regex)
    k_isa_regex = isa key, 'Sub' # should be Regex
    unless k_isa_regex, index_loop

  regex_loop:
    match = key(tmps, 'continue' => pos)
    unless match goto mapping
    ind = match.'from'()
    km = match
    inc nhits
    goto check_hit
  index_loop:
    km = key
    # change over to index method
    $S0 = key
    ind = index tmps, $S0, pos
    if ind == -1 goto mapping
    inc nhits
  check_hit:
    klen = km.'chars'()     # should work for Match, Str
    $I0 = exists itable[ind]
    unless $I0, new_hit
    prev_key = itable[ind;0]
    # keep longest hit at that index
    $I1 = prev_key.'chars'()
    if klen < $I1 goto next_hit
  new_hit:
    $P1 = root_new ['parrot';'ResizablePMCArray']
    push $P1, km
    push $P1, val
    itable[ind] = $P1
  next_hit:
    prev_pos = ind
    pos = ind + klen
    prev_val = val
    unless k_isa_regex goto index_loop
    # Do we just grab the next match (which may backtrack), or only grab longest
    # match? This will affect closures ...
    goto regex_loop

  init_trans:
    .local pmc hit_set, inv_set, inv_table, it
    .local int kvdiff, llm, pr_pos, st, end
    .local string vs
    hit_set = root_new ['parrot';'ResizableIntegerArray']
  normal_hits:
    hit_set = itable.'keys'()
    hit_set = hit_set.'sort'(by)
    unless comp, st_trans
  comp_hits:
    # if :c is indicated, rebuild complement set and use that instead
    # of original itable
    inv_table = new ['Perl6Hash']
    st = 0
    end = 0
    len = length tmps
    inv_set = root_new ['parrot';'ResizableIntegerArray']
    it = hit_set.'iterator'()
  comp_loop1:
    unless it, fence_post
    end = shift it
    key = itable[end;0]
    klen = key.'chars'()
  comp_loop2:
    if st == len goto finish_comp
    if st == end goto comp_loop3
    # TODO: unspec'd behavior
    # depending on how we want to implement complement, we could
    # modify the following to replace the entire unmatched range once
    # or each char (latter implemented for now to match tests)
    push inv_set, st
    $P1 = root_new ['parrot';'ResizablePMCArray']
    push $P1, 'x' # placeholder char; we can replace with substr if needed
    push $P1, comp_match
    inv_table[st] = $P1
    inc st
    goto comp_loop2
  comp_loop3:
    st += klen
    goto comp_loop1
  fence_post:
    end = len
    goto comp_loop2
  finish_comp:
    hit_set = inv_set
    itable = inv_table

  st_trans:
    .local int k_isa_match, v_isa_closure, pass_match
    .local pmc lastmatch, v
    lastmatch = new ['Str']
    lastmatch = ''
    pos = 0 # original unadjusted position
    pr_pos = 0 # prior unadjusted position
    adjpos = 0 # adjusted position
    kvdiff = 0 # key-value string length diff
    klen = 0 # key len
    vlen = 0 # val len
    llm = 0 # orig end marker for longest leftmost match
    tmps = self # reassig; workaround for [perl #59730]

  table_loop:
    unless hit_set, done
    pos = shift hit_set
    if pos < llm goto table_loop
    key = itable[pos;0]
    k_isa_match = isa key, ['PGE';'Match']
    klen = key.'chars'()
    # skip matches between pos and end of llm
    llm = pos + klen
    val = itable[pos;1]
    v_isa_closure = isa val, 'Sub'
    pass_match = k_isa_match && v_isa_closure
    unless v_isa_closure, not_closure
    unless pass_match, simple_closure
  regex_closure:
    val = val(key)
    goto not_closure
  simple_closure:
    val = val()
  not_closure:
    vlen = val.'chars'()
  check_squash:
    unless squash, replace
    # should these be stringified prior to squash?
    unless lastmatch goto replace
    unless val == lastmatch goto replace
    $I0 = pos - prev_pos
    unless $I0 == klen goto replace
    vlen = 0
    prev_pos = pos
    pos += adjpos
    substr tmps, pos, klen, ''
    goto next_pos
  replace:
    prev_pos = pos
    pos += adjpos
    $S0 = val
    substr tmps, pos, klen, $S0
  next_pos:
    kvdiff = klen - vlen
    adjpos -= kvdiff
    lastmatch = val
    goto table_loop

  done:
    retv = tmps
    .return(retv)
.end


=item subst

 our Str method Str::subst ( Any $string: Any $substring, Any $replacement )
 our Str method Str::subst ( Any $string: Code $regexp,   Any $replacement )

Replaces the first occurrence of a given substring or a regular expression
match with some other substring.

Partial implementation. The :g modifier on regexps doesn't work, for example.

=cut

.sub 'subst' :method :multi(_, _, _)
    .param string substring
    .param string replacement
    .param pmc options         :slurpy :named

    .local pmc global_flag
    global_flag = options['global']
    unless null global_flag goto have_global
    global_flag = options['g']
    unless null global_flag goto have_global
    global_flag = get_hll_global ['Bool'], 'False'
  have_global:

    .local int times                    # how many times to substitute
    times = 1                           # the default is to substitute once
    unless global_flag goto check_x
    times = -1                          # a negative number means all of them (:global)
  check_x:

    .local pmc x_opt
    x_opt = options['x']
    if null x_opt goto check_nth
    times = x_opt
    if times < 0 goto x_fail
  check_nth:

    .local pmc nth_opt
    nth_opt = options['nth']
    unless null nth_opt goto check_global
    nth_opt = get_hll_global ['Bool'], 'True'
  check_global:


    .local string result
    result = self
    result = clone result

    if times == 0 goto subst_done

    .local int startpos, pos, substringlen, replacelen
    startpos = 0
    pos = 0
    substringlen = length substring
    replacelen = length replacement
    .local int n_cnt, x_cnt
    n_cnt = 0
    x_cnt = 0
  subst_loop:
    pos = index result, substring, startpos
    startpos = pos + substringlen
    if pos < 0 goto subst_done

    n_cnt += 1
    $P0 = nth_opt.'ACCEPTS'(n_cnt)
    unless $P0 goto subst_loop

    if times < 0 goto skip_times

    x_cnt += 1
    if x_cnt > times goto subst_done
  skip_times:

    substr result, pos, substringlen, replacement
    startpos = pos + replacelen
    goto subst_loop
  subst_done:
    if null x_opt goto x_check_done
    if n_cnt >= times goto x_check_done
    .return (self)
  x_check_done:
    .return (result)

  nth_fail:
    'die'("Must pass a non-negative integer to :nth()")

  x_fail:
    'die'("Must pass a non-negative integer to :x()")
.end


.sub 'subst' :method :multi(_, 'Sub', _)
    .param pmc regex
    .param pmc replacement
    .param pmc options         :slurpy :named

    .local pmc global_flag
    global_flag = options['global']
    unless null global_flag goto have_global
    global_flag = options['g']
    unless null global_flag goto have_global
    global_flag = get_hll_global ['Bool'], 'False'
  have_global:


    .local int times                    # how many times to substitute
    times = 1                           # the default is to substitute once
    unless global_flag goto check_x
    times = -1                          # a negative number means all of them (:global)
  check_x:

    .local pmc x_opt
    x_opt = options['x']
    if null x_opt goto check_nth
    times = x_opt
    if times < 0 goto x_fail
  check_nth:

    .local pmc nth_opt
    nth_opt = options['nth']
    unless null nth_opt goto build_matches
    nth_opt = get_hll_global ['Bool'], 'True'

  build_matches:
    .local string source, result
    source = self
    result = clone source

    if times == 0 goto subst_done

    # build a list of matches
    .local pmc matchlist, match
    .local int n_cnt, x_cnt
    n_cnt = 0
    x_cnt = 0
    matchlist = root_new ['parrot';'ResizablePMCArray']
    match = regex.'!invoke'(source)
    unless match goto matchlist_done

  matchlist_loop:
    n_cnt += 1
    $P0 = nth_opt.'ACCEPTS'(n_cnt)
    unless $P0 goto skip_push

    if times < 0 goto skip_times

    x_cnt += 1
    if x_cnt > times goto matchlist_done
  skip_times:

    push matchlist, match
  skip_push:

    $I0 = match.'to'()
    match = regex(match, 'continue'=>$I0)
    unless match goto matchlist_done
    goto matchlist_loop
  matchlist_done:

    # get caller's lexpad
    .local pmc lexpad
    $P0 = getinterp
    lexpad = $P0['lexpad';1]

    # now, perform substitutions on matchlist until done
    .local int offset
    offset = 0
  subst_loop:
    unless matchlist goto subst_done
    match = shift matchlist
    lexpad['$/'] = match
    # get substitution string
    .local string replacestr
    $I0 = isa replacement, 'Sub'
    if $I0 goto replacement_sub
    replacestr = replacement
    goto have_replacestr
  replacement_sub:
    replacestr = replacement(match)
  have_replacestr:
    # perform the replacement
    $I0 = match.'from'()
    $I1 = match.'to'()
    $I2 = $I1 - $I0
    $I0 += offset
    substr result, $I0, $I2, replacestr
    $I3 = length replacestr
    $I3 -= $I2
    offset += $I3
    goto subst_loop
  subst_done:
    if null x_opt goto x_check_done
    if n_cnt >= times goto x_check_done
    .return (self)
  x_check_done:
    .return (result)

  nth_fail:
    die "Must pass a non-negative integer to :nth()"

  x_fail:
    die "Must pass a non-negative integer to :x()"
.end

# Local Variables:
#   mode: pir
#   fill-column: 100
# End:
# vim: expandtab shiftwidth=4 ft=pir:
