"""
    @enum MatchFail hardfail softfail

This enum is used for distinguishing between two types of failures when trying to 
match a `RuleNode` either with another `RuleNode` or with an `AbstractMatchNode`
  - Hardfail means that there is no match, and there is no way to fill in the holes to get a match.
  - Softfail means that there is no match, but there *might* be a way to fill the holes that results in a match.

"""
@enum MatchFail hardfail softfail
