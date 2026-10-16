local testcase = require('testcase')
local assert = require('assert')
local new_samples = require('measure.samples').new
local welcht = require('measure.compare.welcht')

--- Create fixed samples with equal, nonzero variance for deterministic comparisons.
--- @param name string Unique case name
--- @param offset number Nanoseconds added to each of the five fixed sample times
--- @return measure.samples samples Restored native samples without clock or RNG dependence
local function new_group(name, offset)
    return assert(new_samples({
        name = name,
        capacity = 5,
        count = 5,
        gc_step = 0,
        base_kb = 1,
        cl = 95,
        rciw = 5,
        time_ns = { 100 + offset, 110 + offset, 120 + offset,
                    130 + offset, 140 + offset },
        before_kb = { 0, 0, 0, 0, 0 },
        after_kb = { 0, 0, 0, 0, 0 },
    }))
end

--- Assert that membership indices, names, and all pair decisions agree with the CLD.
--- Cases may belong to several columns, but each membership must reference a
--- real column containing that case and each pair must have the correct overlap.
--- @param result measure.compare.welcht.result Comparison result under verification
--- @param samples measure.samples[] Original input order used by the comparison
local function check_cld(result, samples)
    local groups = result.groups
    local present = {}
    for rank, group in ipairs(groups) do
        assert.equal(group.rank, rank)
        assert.is_string(group.letter)
        assert.equal(#group.names, #group.members)
        assert.greater(#group.members, 0)
        local seen = {}
        for i, member in ipairs(group.members) do
            assert.is_nil(seen[member])
            seen[member] = true
            present[member] = true
            assert.equal(group.names[i], samples[member]:name())
        end
    end
    for i, sample in ipairs(samples) do
        assert.is_true(present[i])
        local memberships = groups[sample:name()]
        local expected = 0
        for _, group in ipairs(groups) do
            for _, member in ipairs(group.members) do
                if member == i then
                    expected = expected + 1
                end
            end
        end
        assert.equal(#memberships, expected)
        local seen = {}
        for _, group in ipairs(memberships) do
            assert.equal(groups[group.rank], group)
            assert.is_nil(seen[group.rank])
            seen[group.rank] = true
            local found = false
            for _, name in ipairs(group.names) do
                if name == sample:name() then
                    found = true
                end
            end
            assert.is_true(found)
        end
    end
    -- Independent invariant: the display must encode every pair decision.
    for _, pair in ipairs(result.pairs) do
        local shared = false
        for _, left in ipairs(groups[pair.name1]) do
            for _, right in ipairs(groups[pair.name2]) do
                if left == right then
                    shared = true
                end
            end
        end
        assert.equal(shared, not pair.significant)
    end
end

--- Verify that a non-transitive three-case result gives the middle case both letters.
function testcase.nontransitive_pairs_have_overlapping_letters()
    local samples = {
        new_group('A', 0), new_group('B', 20), new_group('C', 40),
    }
    local result = welcht(samples)
    assert.greater(result.pairs.A.B.p_adjusted, 0.05)
    assert.greater(result.pairs.B.C.p_adjusted, 0.05)
    assert.less(result.pairs.A.C.p_adjusted, 0.05)
    assert.equal(#result.groups, 2)
    assert.equal(#result.groups.A, 1)
    assert.equal(#result.groups.B, 2)
    assert.equal(#result.groups.C, 1)
    check_cld(result, samples)
end

--- Verify pairwise CLD relations for all six orders of a non-transitive example.
function testcase.nontransitive_pairs_in_every_input_order()
    local a, b, c = new_group('A', 0), new_group('B', 20), new_group('C', 40)
    for _, samples in ipairs({
        {a, b, c}, {a, c, b}, {b, a, c},
        {b, c, a}, {c, a, b}, {c, b, a},
    }) do
        local result = welcht(samples)
        assert.equal(#result.groups, 2)
        assert.equal(#result.groups.B, 2)
        check_cld(result, samples)
    end
end

--- Verify that mutually non-significant cases share one letter column.
function testcase.all_nonsignificant_pairs_share_one_letter()
    local samples = {
        new_group('A', 0), new_group('B', 0),
        new_group('C', 0), new_group('D', 0),
    }
    local result = welcht(samples)
    assert.equal(#result.groups, 1)
    assert.equal(result.groups[1].members, {1, 2, 3, 4})
    assert.equal(result.groups[1].letter, 'a')
    check_cld(result, samples)
end

--- Verify that mutually significant cases have separate letter columns.
function testcase.all_significant_pairs_have_distinct_letters()
    local samples = {
        new_group('A', 0), new_group('B', 100),
        new_group('C', 200), new_group('D', 300),
    }
    local result = welcht(samples)
    assert.equal(#result.groups, 4)
    for _, pair in ipairs(result.pairs) do
        assert.is_true(pair.significant)
    end
    check_cld(result, samples)
end

--- Verify that interleaved inputs retain original member indices and name lookups.
function testcase.interleaved_groups_preserve_indices_and_mapping()
    local samples = {
        new_group('A', 0), new_group('C', 100),
        new_group('B', 1), new_group('D', 101),
    }
    local result = welcht(samples)
    assert.equal(#result.groups, 2)
    check_cld(result, samples)
end

--- Verify that a five-case gradient encodes every pairwise decision.
function testcase.five_case_display_matches_every_pair()
    local samples = {}
    for i = 1, 5 do
        samples[i] = new_group('case' .. i, (i - 1) * 25)
    end
    check_cld(welcht(samples), samples)
end

--- Verify repeatable letter memberships without mutating the input order.
function testcase.display_is_deterministic_without_reordering_input()
    local samples = {
        new_group('B', 20), new_group('C', 40), new_group('A', 0),
    }
    local first, second = welcht(samples), welcht(samples)
    assert.equal(#first.groups, #second.groups)
    for i, group in ipairs(first.groups) do
        assert.equal(group.names, second.groups[i].names)
        assert.equal(group.members, second.groups[i].members)
        assert.equal(group.letter, second.groups[i].letter)
    end
    assert.equal(samples[1]:name(), 'B')
    assert.equal(samples[2]:name(), 'C')
    assert.equal(samples[3]:name(), 'A')
    check_cld(first, samples)
end

--- Verify unique letter tokens beyond z and correct memberships for 27 cases.
function testcase.letters_extend_beyond_the_alphabet()
    local samples = {}
    for i = 1, 27 do
        samples[i] = new_group('case' .. i, i * 10000)
    end
    local result = welcht(samples)
    assert.equal(#result.groups, 27)
    local labels = {}
    for _, group in ipairs(result.groups) do
        assert.is_nil(labels[group.letter])
        labels[group.letter] = true
    end
    assert.is_true(labels.a)
    assert.is_true(labels.z)
    assert.is_true(labels.aa)
    check_cld(result, samples)
end

--- Verify that method metadata describes CLD without claiming equivalence.
function testcase.description_explains_cld_interpretation()
    local result = welcht({new_group('A', 0), new_group('B', 20)})
    assert.match(result.clustering, 'compact letter display', true)
    assert.match(result.clustering, 'does not establish statistical equivalence', true)
end
