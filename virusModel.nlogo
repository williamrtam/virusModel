globals [number-vaccinated number-infected number-quarantine quarantine-count] ;global variables defining numbers from percentages on sliders (also # associated with "quarantined" monitor)
turtles-own [vision sick-duration convince-vaccination time-count cough-timer nearest-infected antipathy sympathy decay-timer flee joy distress patience endurance endurance-timer compliance tried-vacc] ;vision agent variable and counters for if fatal? and/or can-vaccinate? are on
links-own [active]
directed-link-breed [chases chase]
directed-link-breed [awarenesses awareness]

to setup ;initializes world, global, and turtle variables
  clear-all
  resize-world 0 world-size 0 world-size
  setup-others
  setup-vision
  setup-jail
  ask turtles [ set shape "person"]
  set quarantine-count 0
  reset-ticks
end

to setup-others ;infected agents are red, uninfected agents are white, and vaccinated agents are yellow (all with random initial locations)
  set number-vaccinated number-people * percent-vaccinated ;initialize global variable
  create-turtles number-vaccinated [set color yellow]
  set number-infected number-people * percent-infected ;initialize global variable
  create-turtles number-infected [set color red]
  create-turtles number-people - number-vaccinated - number-infected [set color white]
  set number-quarantine number-people * percent-quarantine ;initialize global variable
  create-turtles number-quarantine [set color blue]
  ask turtles with [color != blue] [
    setxy random-xcor random-ycor
    set sick-duration 0 - random 40 ;initialize turtle variable (random 40 sets random lower bound of counter for each turtle)
    set convince-vaccination 0 - random 40 ;initialize turtle variable (random 40 sets random lower bound of counter for each turtle)
    set time-count 0
    set cough-timer random time-to-cough
    set nearest-infected nobody
    set antipathy 0
    set sympathy 0
    set decay-timer 0
    set flee 0
    set compliance random 100
    set tried-vacc 0
    ifelse compliance > compliance-probability [set compliance 0] [set compliance 1]
  ]
  ask turtles with [color = blue] [
    setxy random-xcor random-ycor
    set nearest-infected nobody
    set decay-timer 0
    set patience 10 + random 10
    set endurance 0
    set endurance-timer endurance-limit + random 10
  ]
end

to setup-vision ;initialize turtle vision
  ask turtles [
    ifelse color = blue ;quarantine officers have different vision constraints
    [ set vision min-quarantine-vision + random 5 ]
    [ set vision min-normal-vision + random 5 ]
  ]
end

to setup-jail ;constructs the jail for quarantine in middle of world
  ask (patch-set patch (world-size / 2) (world-size / 2) patch (world-size / 2) ((world-size / 2) + 1)
    patch ((world-size / 2) + 1) (world-size / 2) patch ((world-size / 2) + 1) ((world-size / 2) + 1)) [
    set pcolor green
  ]
end

to go
  move-turtles ;all turtle actions within move-turtle function and helpers
  disease-update ;increments sick-duration if fatal? to check whether infected agents die
  tick
end

to move-turtles
  ask turtles [
    if color = blue [ ;actions of quarantine officers
      set decay-timer decay-timer + 1 ;increment emotional decay count
      if decay-timer > decay-interval [set decay-timer 0
        if joy != 0 [ifelse joy > 0 [set joy joy - 1
          set distress distress + 1]
          [set joy joy + 1
            set distress distress - 1] ] ]
      if any? turtles with [color = sky or color = pink] and nearest-infected = nobody [ ;check for null
        set nearest-infected min-one-of turtles with [color = sky or color = pink] [distance myself]
        let dist [distance myself] of nearest-infected
        if dist > vision [set nearest-infected nobody]
        ifelse nearest-infected != nobody and out-chase-neighbor? nearest-infected [ask out-chase-to nearest-infected [show-link]
        set patience joy + random 5]
        [if nearest-infected != nobody [create-chase-to nearest-infected] ] ] ;finds closest infected and calculates dist
      if any? turtles with [flee = 1] and nearest-infected = nobody [
        set nearest-infected min-one-of turtles with [flee = 1] [distance myself]
        let dist [distance myself] of nearest-infected
        if dist > vision [set nearest-infected nobody]
        if nearest-infected != nobody [create-chase-to nearest-infected] ]
      ifelse nearest-infected != nobody [let dist [distance myself] of nearest-infected
        if not out-chase-neighbor? nearest-infected [create-chase-to nearest-infected]
          set patience patience - 1
          set endurance endurance + 1
      ifelse endurance > endurance-limit
        [set endurance -5
          ask out-chase-to nearest-infected [hide-link]
         set nearest-infected nobody
         set patience joy + 10 + random 10
         set color lime] [
      if patience < 0 and stun? and dist < stun-range [
            ask nearest-infected [set color pink] ]
      if dist < quarantine-speed [ ;if the infected agent is close enough to catch
            ask nearest-infected [set flee 1]
          set heading towards nearest-infected
          check-jail
        fd dist
            ifelse [color] of nearest-infected = pink [set joy joy - 1
              set distress distress + 1]
            [set joy joy + 1
              set distress distress - 1]
            ask turtles with [color = white] in-radius emotion-range [
              if any? out-awareness-neighbors [
              ifelse out-awareness-neighbor? nearest-infected [
                set antipathy antipathy - 1
                  set sympathy sympathy + 1 ]
              [set antipathy antipathy - 2
                  set sympathy sympathy + 2] ] ]
          ask nearest-infected [die]
          set patience joy + 10 + random 10
          set color gray  ;quarantined officers holding an infected agent are gray
      ]
      if dist > quarantine-speed and dist < vision [ ;if close enough to see but not catch
            ask nearest-infected [set flee 1]
        set heading towards nearest-infected
          check-jail
        fd quarantine-speed
      ]
      if dist > vision [ ;if the QO cannot see the nearest infected
        set heading random 360
          check-jail
        fd quarantine-speed
      ] ] ]
      [ set heading random 360 ;this will happen if there are no infected agents left
        check-jail
        fd quarantine-speed ]
    ]

    if color = lime [
      set endurance endurance + 1
      if endurance = 0 [set color blue]
      if endurance > 0 [set endurance 0
        set color blue]
    ]

    if color = red or color = sky [ ;actions of infected agents
;      set time-count time-count + 1
;      if time-count >= cough-timer [set time-count 0
;      set color sky]
      let coughprob random 100
        if coughprob <= cough-probability [set color sky]
      ifelse run-from-quarantine? and compliance = 0 ;checks if infected agents attempt to escape or if they comply
      [
      ifelse any? turtles with [color = blue or color = lime] and flee = 1 [ ;check for null
        let nearest-quarantine min-one-of turtles with [color = blue or color = lime] [distance myself] ;finds closest QO and calculates dist
        let dist [distance myself] of nearest-quarantine
        ifelse dist < vision [ ;if they can see the officer, they run away
          face nearest-quarantine
          rt 180
            check-jail
          fd 1
            if color = red [fd 1]
        ]
     [ set heading random 360 ;this will happen if they do not see the nearest QO
            check-jail
          fd 1 ] ]
      [ set heading random 360 ;this will happen if there are no QO
          check-jail
          fd 1 ] ]
      [ set heading random 360 ;this will happen if they do not attempt to escape
        check-jail
        fd 1]
;      if any? turtles with [color = white] [
;        let nearest-healthy min-one-of turtles with [color = white] [distance myself]
;        let dist [distance myself] of nearest-healthy
;        if dist < 2 [ ask nearest-healthy [set color red] ]
;        ]
    if color = sky [
      set time-count time-count + 1
      if time-count > cough-duration [set time-count 0
        set color red]
      if any? turtles with [color = white] [
        let nearest-healthy min-one-of turtles with [color = white] [distance myself]
        let dist [distance myself] of nearest-healthy
        if dist < 3 [
            let prob random 100
            if prob <= infection-probability [
              ask nearest-healthy [set color red] ]
        ask turtles with [color = white] in-radius emotion-range [
          set sympathy sympathy - 1
          set antipathy antipathy + 1]]
        ]
    ] ]

    if color = white or color = yellow [ ;actions of uninfected and vaccinated agents are the same
      set decay-timer decay-timer + 1 ;increment emotional decay count
      if decay-timer > decay-interval [set decay-timer 0
        if sympathy != 0 [ifelse sympathy > 0 [set sympathy sympathy - 1
          set antipathy antipathy + 1]
          [set sympathy sympathy + 1
            set antipathy antipathy - 1] ] ]
      ifelse run-from-infected? [
       let prob-aware random 100 ;checks if uninfected/vaccinated agents attempt to avoid infected agents
      ifelse any? turtles with [color = sky] [ ;checks for null
        set nearest-infected min-one-of turtles with [color = sky] [distance myself] ;finds closest infected agent and calculates dist
        let dist [distance myself] of nearest-infected
        ifelse dist < vision and prob-aware <= awareness-probability [ ;if they can see the infected agent, they run away
            if not out-awareness-neighbor? nearest-infected [create-awareness-to nearest-infected
              ask my-out-awarenesses [hide-link]
            ]
            face nearest-infected
          rt 180
            check-jail
          fd 1]
        [set heading random 360 ;this will happen if they do not see the nearest infected
            check-jail
            fd 1] ]
       [
      ifelse any? turtles with [color = red] and any? out-awareness-neighbors [
            let nearest-aware-infected min-one-of out-awareness-neighbors [distance myself]
            let dist2 [distance myself] of nearest-aware-infected
            ifelse dist2 < vision and prob-aware <= awareness-probability [face nearest-aware-infected
          rt 180
            check-jail
          fd 1]
          [set heading random 360 ;this will happen if there are no infected agents
          check-jail
            fd 1] ]
          [set heading random 360 ;this will happen if they do not see the nearest infected
            check-jail
            fd 1 ] ] ]
      [set heading random 360 ;this will happen if they do not attempt to run away from infected agents
        check-jail
          fd 1]
      if color = white and can-vaccinate? [ ;uninfected check for whether or not it will vaccinate
        if any? turtles with [color = yellow]
        [let nearest-vaccinated min-one-of turtles with [color = yellow] [distance myself] ;checks if nearest vaccinated agent is within vision
          let dist [distance myself] of nearest-vaccinated
          if decay-timer = 0 [set convince-vaccination convince-vaccination - 1]
        if dist < 1 [
          set convince-vaccination convince-vaccination + 1 ;increments turtle variable
            if convince-vaccination > vaccination-threshold [
              let vacc-prob random 100
              if vacc-prob <= vacc-success-probability and tried-vacc = 0 [set color yellow]
            set tried-vacc 1] ;if set threshold is exceeded, they receive vaccination
        ]
      ] ]
      if antipathy > antipathy-threshold [set color blue]
      if sympathy > sympathy-threshold and can-vaccinate? [set color yellow] ]

   if color = gray [ ;actions of quarantine officer that has captured an infected agent
        ifelse patch-here = patch (world-size / 2) (world-size / 2) [ ;if they have arrived at the jail
          set quarantine-count quarantine-count + 1 ;place the infected agent in quarantine
          set color blue ;become available to seek another infected agent
          fd quarantine-speed
        ]
        [
          set heading towards patch (world-size / 2) (world-size / 2) ;if they are not at the jail, the turn towards it
        let dist [distance myself] of patch (world-size / 2) (world-size / 2) ;will stop at jail if it is within one tick walking distance
        ifelse dist < 1 [ fd dist ]
        [ fd 1 ]
        ]
    ]
  ]

end

to disease-update ;if disease is fatal, updates sick-duration to check if individual agents should die
  ask turtles [
    if color = red or color = sky and fatal? [ ;if they are infected and the disease is fatal
  set sick-duration sick-duration + 1 ;increment turtle variable
  if sick-duration >= lifespan-infected [ die ] ;checks for death
    ]
  ]
end

to check-jail ;prevents turtles other than quarantine officers with captured infected agents from entering the jail
  while [[pcolor] of patch-ahead 1 = green or [pcolor] of patch-ahead 2 = green or [pcolor] of patch-ahead 3 = green or [pcolor] of patch-ahead 4 = green] [ rt random 360 ]
end
@#$#@#$#@
GRAPHICS-WINDOW
812
10
1639
838
-1
-1
13.0
1
10
1
1
1
0
1
1
1
0
62
0
62
0
0
1
ticks
30.0

SLIDER
13
83
186
116
percent-quarantine
percent-quarantine
0
0.1
0.01
0.01
1
NIL
HORIZONTAL

BUTTON
13
22
76
55
go
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
98
22
161
55
setup
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
16
142
188
175
min-quarantine-vision
min-quarantine-vision
10
40
15.0
1
1
NIL
HORIZONTAL

SLIDER
18
199
190
232
min-normal-vision
min-normal-vision
5
20
10.0
1
1
NIL
HORIZONTAL

SLIDER
17
299
199
332
percent-infected
percent-infected
0
0.20
0.1
0.01
1
NIL
HORIZONTAL

SLIDER
20
252
192
285
number-people
number-people
0
500
500.0
1
1
NIL
HORIZONTAL

SLIDER
16
350
200
383
percent-vaccinated
percent-vaccinated
0
0.10
0.05
0.01
1
NIL
HORIZONTAL

SLIDER
17
407
189
440
lifespan-infected
lifespan-infected
0
100
100.0
1
1
NIL
HORIZONTAL

SLIDER
20
460
192
493
quarantine-speed
quarantine-speed
1
5
2.0
1
1
NIL
HORIZONTAL

SWITCH
6
521
180
554
run-from-quarantine?
run-from-quarantine?
0
1
-1000

SWITCH
6
568
165
601
run-from-infected?
run-from-infected?
0
1
-1000

SWITCH
5
623
95
656
fatal?
fatal?
1
1
-1000

MONITOR
19
676
77
721
infected
count turtles with [color = red or color = sky or color = pink]
17
1
11

MONITOR
88
677
160
722
uninfected
count turtles with [color = white]
17
1
11

MONITOR
250
677
323
722
vaccinated
count turtles with [color = yellow]
17
1
11

SLIDER
9
731
181
764
world-size
world-size
10
70
62.0
2
1
NIL
HORIZONTAL

MONITOR
333
678
413
723
quarantined
quarantine-count
17
1
11

SLIDER
11
783
183
816
vaccination-threshold
vaccination-threshold
0
100
75.0
1
1
NIL
HORIZONTAL

SWITCH
198
783
337
816
can-vaccinate?
can-vaccinate?
0
1
-1000

SLIDER
222
96
394
129
time-to-cough
time-to-cough
20
1000
20.0
1
1
NIL
HORIZONTAL

SLIDER
220
140
392
173
cough-duration
cough-duration
0
10
5.0
1
1
NIL
HORIZONTAL

SLIDER
220
178
392
211
antipathy-threshold
antipathy-threshold
0
100
59.0
1
1
NIL
HORIZONTAL

SLIDER
219
229
391
262
sympathy-threshold
sympathy-threshold
0
100
10.0
1
1
NIL
HORIZONTAL

MONITOR
177
679
234
724
QO
count turtles with [color = blue or color = gray or color = lime]
17
1
11

SLIDER
222
10
394
43
decay-interval
decay-interval
10
30
20.0
1
1
NIL
HORIZONTAL

SWITCH
104
623
207
656
stun?
stun?
0
1
-1000

SLIDER
219
282
391
315
stun-range
stun-range
2
50
5.0
1
1
NIL
HORIZONTAL

PLOT
216
383
483
585
Agent Count
time
number
0.0
10.0
0.0
350.0
true
false
"" ""
PENS
"uninfected" 1.0 0 -16777216 true "" "plot count turtles with [color = white]"
"infected" 1.0 0 -2674135 true "" "plot count turtles with [color = red or color = sky]"
"vaccinated" 1.0 0 -1184463 true "" "plot count turtles with [color = yellow]"
"quarantine officer" 1.0 0 -13345367 true "" "plot count turtles with [color = blue or color = gray]"
"quarantined" 1.0 0 -7500403 true "" "plot quarantine-count"

SLIDER
220
334
392
367
emotion-range
emotion-range
10
100
15.0
1
1
NIL
HORIZONTAL

SLIDER
222
51
394
84
endurance-limit
endurance-limit
0
100
30.0
1
1
NIL
HORIZONTAL

SLIDER
218
605
390
638
compliance-probability
compliance-probability
0
100
50.0
1
1
NIL
HORIZONTAL

SLIDER
426
12
598
45
infection-probability
infection-probability
0
100
50.0
1
1
NIL
HORIZONTAL

SLIDER
430
53
602
86
cough-probability
cough-probability
0
100
11.0
1
1
NIL
HORIZONTAL

SLIDER
429
99
601
132
awareness-probability
awareness-probability
0
100
100.0
1
1
NIL
HORIZONTAL

SLIDER
428
142
613
175
vacc-success-probability
vacc-success-probability
0
100
50.0
1
1
NIL
HORIZONTAL

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.0.2
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
