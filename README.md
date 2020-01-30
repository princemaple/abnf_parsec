# AbnfParsec

**TODO: Add description**

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `abnf_parsec` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:abnf_parsec, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/abnf_parsec](https://hexdocs.pm/abnf_parsec).

### Parsing Example

ABNF of ABNF is parsed

```
rulelist       =  1*( rule / (*c-wsp c-nl) )

rule           =  rulename defined-as elements c-nl
                      ; continues if next line starts
                      ;  with white space

rulename       =  ALPHA *(ALPHA / DIGIT / "-")

defined-as     =  *c-wsp ("=" / "=/") *c-wsp
                      ; basic rules definition and
                      ;  incremental alternatives

elements       =  alternation *c-wsp

c-wsp          =  WSP / (c-nl WSP)

c-nl           =  comment / CRLF
                      ; comment or newline

comment        =  ";" *(WSP / VCHAR) CRLF

alternation    =  concatenation
                 *(*c-wsp "/" *c-wsp concatenation)

concatenation  =  repetition *(1*c-wsp repetition)

repetition     =  [repeat] element

repeat         =  1*DIGIT / (*DIGIT "*" *DIGIT)

element        =  rulename / group / option /
                 char-val / num-val / prose-val

group          =  "(" *c-wsp alternation *c-wsp ")"

option         =  "[" *c-wsp alternation *c-wsp "]"

char-val       =  DQUOTE *(%x20-21 / %x23-7E) DQUOTE
                      ; quoted string of SP and VCHAR
                      ;  without DQUOTE

num-val        =  "%" (bin-val / dec-val / hex-val)

bin-val        =  "b" 1*BIT
                 [ 1*("." 1*BIT) / ("-" 1*BIT) ]
                      ; series of concatenated bit values
                      ;  or single ONEOF range

dec-val        =  "d" 1*DIGIT
                 [ 1*("." 1*DIGIT) / ("-" 1*DIGIT) ]

hex-val        =  "x" 1*HEXDIG
                 [ 1*("." 1*HEXDIG) / ("-" 1*HEXDIG) ]

prose-val      =  "<" *(%x20-3D / %x3F-7E) ">"
                      ; bracketed string of SP and VCHAR
                      ;  without angles
                      ; prose description, to be used as
                      ;  last resort
```

into

```elixir
[
  rule: [
    rulename: "rulelist",
    repetition: [
      repeat: [min: 1],
      alternation: [
        rulename: "rule",
        concatenation: [
          repetition: [repeat: [], rulename: "c-wsp"],
          rulename: "c-nl"
        ]
      ]
    ]
  ],
  rule: [
    rulename: "rule",
    concatenation: [
      rulename: "rulename",
      rulename: "defined-as",
      rulename: "elements",
      rulename: "c-nl"
    ],
    comment: "continues if next line starts",
    comment: "with white space"
  ],
  rule: [
    rulename: "rulename",
    concatenation: [
      rulename: "ALPHA",
      repetition: [
        repeat: [],
        alternation: [{:rulename, "ALPHA"}, {:rulename, "DIGIT"}, "-"]
      ]
    ]
  ],
  rule: [
    rulename: "defined-as",
    concatenation: [
      repetition: [repeat: [], rulename: "c-wsp"],
      alternation: ["=", "=/"],
      repetition: [repeat: [], rulename: "c-wsp"]
    ],
    comment: "basic rules definition and",
    comment: "incremental alternatives"
  ],
  rule: [
    rulename: "elements",
    concatenation: [
      rulename: "alternation",
      repetition: [repeat: [], rulename: "c-wsp"]
    ]
  ],
  rule: [
    rulename: "c-wsp",
    alternation: [
      rulename: "WSP",
      concatenation: [rulename: "c-nl", rulename: "WSP"]
    ]
  ],
  rule: [
    rulename: "c-nl",
    alternation: [rulename: "comment", rulename: "CRLF"],
    comment: "comment or newline"
  ],
  rule: [
    rulename: "comment",
    concatenation: [
      ";",
      {:repetition,
       [repeat: [], alternation: [rulename: "WSP", rulename: "VCHAR"]]},
      {:rulename, "CRLF"}
    ]
  ],
  rule: [
    rulename: "alternation",
    concatenation: [
      rulename: "concatenation",
      repetition: [
        repeat: [],
        concatenation: [
          {:repetition, [repeat: [], rulename: "c-wsp"]},
          "/",
          {:repetition, [repeat: [], rulename: "c-wsp"]},
          {:rulename, "concatenation"}
        ]
      ]
    ]
  ],
  rule: [
    rulename: "concatenation",
    concatenation: [
      rulename: "repetition",
      repetition: [
        repeat: [],
        concatenation: [
          repetition: [repeat: [min: 1], rulename: "c-wsp"],
          rulename: "repetition"
        ]
      ]
    ]
  ],
  rule: [
    rulename: "repetition",
    concatenation: [option: [rulename: "repeat"], rulename: "element"]
  ],
  rule: [
    rulename: "repeat",
    alternation: [
      repetition: [repeat: [min: 1], rulename: "DIGIT"],
      concatenation: [
        {:repetition, [repeat: [], rulename: "DIGIT"]},
        "*",
        {:repetition, [repeat: [], rulename: "DIGIT"]}
      ]
    ]
  ],
  rule: [
    rulename: "element",
    alternation: [
      rulename: "rulename",
      rulename: "group",
      rulename: "option",
      rulename: "char-val",
      rulename: "num-val",
      rulename: "prose-val"
    ]
  ],
  rule: [
    rulename: "group",
    concatenation: [
      "(",
      {:repetition, [repeat: [], rulename: "c-wsp"]},
      {:rulename, "alternation"},
      {:repetition, [repeat: [], rulename: "c-wsp"]},
      ")"
    ]
  ],
  rule: [
    rulename: "option",
    concatenation: [
      "[",
      {:repetition, [repeat: [], rulename: "c-wsp"]},
      {:rulename, "alternation"},
      {:repetition, [repeat: [], rulename: "c-wsp"]},
      "]"
    ]
  ],
  rule: [
    rulename: "char-val",
    concatenation: [
      rulename: "DQUOTE",
      repetition: [
        repeat: [],
        alternation: [
          num_range: [{:base, "x"}, "20", "21"],
          num_range: [{:base, "x"}, "23", "7E"]
        ]
      ],
      rulename: "DQUOTE"
    ],
    comment: "quoted string of SP and VCHAR",
    comment: "without DQUOTE"
  ],
  rule: [
    rulename: "num-val",
    concatenation: [
      "%",
      {:alternation,
       [rulename: "bin-val", rulename: "dec-val", rulename: "hex-val"]}
    ]
  ],
  rule: [
    rulename: "bin-val",
    concatenation: [
      "b",
      {:repetition, [repeat: [min: 1], rulename: "BIT"]},
      {:option,
       [
         alternation: [
           repetition: [
             repeat: [min: 1],
             concatenation: [
               ".",
               {:repetition, [repeat: [min: 1], rulename: "BIT"]}
             ]
           ],
           concatenation: [
             "-",
             {:repetition, [repeat: [min: 1], rulename: "BIT"]}
           ]
         ]
       ]}
    ],
    comment: "series of concatenated bit values",
    comment: "or single ONEOF range"
  ],
  rule: [
    rulename: "dec-val",
    concatenation: [
      "d",
      {:repetition, [repeat: [min: 1], rulename: "DIGIT"]},
      {:option,
       [
         alternation: [
           repetition: [
             repeat: [min: 1],
             concatenation: [
               ".",
               {:repetition, [repeat: [min: 1], rulename: "DIGIT"]}
             ]
           ],
           concatenation: [
             "-",
             {:repetition, [repeat: [min: 1], rulename: "DIGIT"]}
           ]
         ]
       ]}
    ]
  ],
  rule: [
    rulename: "hex-val",
    concatenation: [
      "x",
      {:repetition, [repeat: [min: 1], rulename: "HEXDIG"]},
      {:option,
       [
         alternation: [
           repetition: [
             repeat: [min: 1],
             concatenation: [
               ".",
               {:repetition, [repeat: [min: 1], rulename: "HEXDIG"]}
             ]
           ],
           concatenation: [
             "-",
             {:repetition, [repeat: [min: 1], rulename: "HEXDIG"]}
           ]
         ]
       ]}
    ]
  ],
  rule: [
    rulename: "prose-val",
    concatenation: [
      "<",
      {:repetition,
       [
         repeat: [],
         alternation: [
           num_range: [{:base, "x"}, "20", "3D"],
           num_range: [{:base, "x"}, "3F", "7E"]
         ]
       ]},
      ">"
    ],
    comment: "bracketed string of SP and VCHAR",
    comment: "without angles",
    comment: "prose description, to be used as",
    comment: "last resort"
  ]
]
```
