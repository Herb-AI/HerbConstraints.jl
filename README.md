# HerbConstraints.jl

This package contains the functionality to formulate, represent and use constraints within `Herb`. 

Constraints are formulated as context-sensitive grammars. Further, they are divided into global and local constraints, that may be partially mapped to each other. 

`HerbConstraints.jl` provides functionality to propagate constraints and match constraint patterns efficiently. Further, provides error handling through `matchfail` and `matchnode`.

[![Build Status](https://github.com/Herb-AI/HerbConstraints.jl/actions/workflows/CI.yml/badge.svg?branch=master)](https://github.com/Herb-AI/HerbConstraints.jl/actions/workflows/CI.yml?query=branch%3Amaster)

