;;Global : U, V, unexpected_company_motivation, firing_treshold, unexpected_firing, unexpected_worker_motivation, max_product_fluctuation, quality_treshold, exceptional_matching_bonus, nb_companies
;;         display_links, salary_sigma, salary mean, sqrt_nb_locations, matches_by_round

globals [ world_width world_height minimal_salary the_matching_agent last_display_links color_set ]

;;workers
breed [ workers worker ]
workers-own [ location salary skills mean_productivity current_productivity unexpected_motivation employer ]

;;companies
breed [ companies company ]
companies-own [ location salary skills unexpected_motivation worker_list ]

;;matching agent
breed [ matching_agents matching_agent ]
matching_agents-own [ worker_list company_hiring_list ]

;;set up the environment
to setup
  clear-all
  reset-ticks
  set last_display_links display_links
  set color_set [ 15 25 35 45 55 65 75 85 95 105 115 125 135 17 27 37 47 57 67 77 87 97 107 117 127 137 ]

  ;;global variables, may be passed as parameters later
  set world_width 100
  set world_height 100
  set minimal_salary 1171
  set matches_by_round 10
  ;;locations and links coloration
  ask patches [
    let  col ceiling ( ( pycor + 1 )  / ( world_height / sqrt_nb_locations ) )
    let line ceiling ( ( pxcor + 1 ) / ( world_width / sqrt_nb_locations ) )
    if ( line + col ) mod 2 = 0 [ set pcolor grey ]

  ]


  ;;matching agent init
  create-matching_agents 1 [
    set worker_list [ ]
    set company_hiring_list [ ]
  ]
  set the_matching_agent matching_agent 0

  ;;workers init
  create-workers U
  [
    ;;genral
    set size 3
    set color white
    set shape "person"
    set employer -1
    set unexpected_motivation false

    ;;location
    let x random world_width
    let y random world_height
    setxy  x y
    set location sqrt_nb_locations * floor ( y  / ( world_height / sqrt_nb_locations ) ) + ceiling ( x / ( world_width / sqrt_nb_locations ) )

    ;;skills
    set skills ( list random 2 random 2 random 2 random 2 random 2 )

    ;;salary
    let tmp_salary floor ( random-normal salary_mean salary_sigma )
    if tmp_salary < minimal_salary [ set tmp_salary  minimal_salary]
    set salary tmp_salary

    ;;mean productivity
    set mean_productivity random-float 1

    ;;employer
    set employer -1

    ;;register as job seeker to the matching agent
    let id who
    register_as_job_seeker id
  ]

  ;;jobs distribution
  let job_distrib [ ]
  while [ ( length job_distrib ) < ( nb_companies - 1 ) ]
  [
    let val -1
    while [ val < 0 or member? val job_distrib ]
    [
      set val ( random V - 2 ) + 1
    ]
    set job_distrib insert-item 0 job_distrib val
  ]
  set job_distrib sort job_distrib
  set job_distrib insert-item 0 job_distrib 0
  set job_distrib insert-item ( length job_distrib ) job_distrib ( V - 1 )

  ;;companies init
  let i 1
  let j 0
  create-companies nb_companies
  [
    ;;genral
    set color item ( i mod ( length color_set ) ) color_set
    set shape "house"
    set worker_list [ ]
    set unexpected_motivation false

    ;;location
    let x random world_width
    let y random world_height
    setxy  x y
    set location sqrt_nb_locations * floor ( y  / ( world_height / sqrt_nb_locations ) ) + ceiling ( x / ( world_width / sqrt_nb_locations ) )

    ;;skills
    set skills ( list random 2 random 2 random 2 random 2 random 2 )

    ;;salary
    let val floor ( random-normal salary_mean salary_sigma )
    if val < minimal_salary [ set val  minimal_salary]
    set salary val

    ;;send job offers to the matching agents
    let id who
    let tmp_nb_job ( item i job_distrib ) - ( item ( i - 1 ) job_distrib )
    while [ j < ( item i job_distrib ) ]
    [
      add_a_job_offer id
      set j j + 1
    ]
    set i i + 1

    ;;set size depending on job number
    set size 3 + 15 * tmp_nb_job / V
  ]
end

;;iteration of the simulation, can be see as day, week...
to simulate
  ;;workers
  workers_action

  ;;companies
  companies_action

  ;;matching
  do_matching

  ;;update env
  graphic_update
  tick
end

;;workers agent on an iteration
to workers_action
  ask workers [
    ifelse not ( employer = -1 )
    ;;employed
    [
      ;; draw current productivity in [mean - fluctuation / 2 , mean + fluctuation / 2 ]
      let tmp_prod ( mean_productivity + ( ( random-float max_product_fluctuation ) - ( max_product_fluctuation / 2 ) ) )
      set tmp_prod min list tmp_prod 1
      set tmp_prod max list tmp_prod 0
      set current_productivity tmp_prod
    ]
    ;;employed
    [
      ;;unexpected motivation this iteration
      let unexp_motiv random-float 1
      ifelse unexp_motiv < unexpected_worker_motivation [ set unexpected_motivation true ] [ set unexpected_motivation false ]

    ]
  ]
end

;;companies agent on an iteration
to companies_action
  ask companies [
    let tmp_prod -1
    let fired [ ]
    ;;evaluate each employee productivity
    foreach worker_list [
      x -> let employee_id x
      ask worker employee_id [
        set tmp_prod current_productivity
      ]
      let unexp_fire random-float 1
      ;; if productivity too low or unexpecti firing, fire
      if tmp_prod < firing_treshold or unexp_fire < unexpected_firing [
        fire employee_id
        set fired insert-item 0 fired employee_id
        ;;show ( word "fired " employee_id  " prod : " tmp_prod )
      ]
    ]

    ;;remove fired from worker_list and create a new job offer
    foreach fired [
      x -> let employee_id x
      set worker_list remove employee_id worker_list
      add_a_job_offer who
    ]

    ;;unexpected motivation this iteration
    let unexp_motiv random-float 1
      ifelse unexp_motiv < unexpected_company_motivation [ set unexpected_motivation true ] [ set unexpected_motivation false ]
  ]
end

;;matching agent on an iteration
to do_matching
  repeat matches_by_round [ match ]
end

;;try to match a pair
to match
  let company_id -1
  let worker_id -1
  let score -1

  let worker_list_ind -1
  let company_list_ind -1

  ;;choose a pair
  ask the_matching_agent [
    if not ( empty? worker_list or empty? company_hiring_list ) [
      set worker_list_ind random ( length worker_list )
      set worker_id item ( worker_list_ind ) worker_list
      set company_list_ind random ( length company_hiring_list )
      set company_id item ( company_list_ind ) company_hiring_list
    ]
  ]

  ;;get score
  if not ( company_id = -1 or worker_id = -1 )[
    set score calculate_score worker_id company_id

    ;;get bonuses if unecpected motivation
    ask worker worker_id [ if unexpected_motivation [ set score score + exceptional_matching_bonus ] ]
    ask company company_id [ if unexpected_motivation [ set score score + exceptional_matching_bonus ] ]
  ]



  ;;if score is good enough, hire and remove form lists
  if score > quality_treshold [
    hire worker_id company_id
    ask the_matching_agent
    [
      set worker_list remove-item worker_list_ind worker_list
      set company_hiring_list remove-item company_list_ind company_hiring_list
    ]
  ]


end

;;used by people to register to the matching agent
to register_as_job_seeker [ id ]
  ask the_matching_agent
    [
      set worker_list insert-item 0 worker_list id
    ]
end

;;used by company to sent a job offer to the matching agent
to add_a_job_offer [ id ]
   ask the_matching_agent
     [
       set company_hiring_list insert-item 0 company_hiring_list id
     ]
end

;;score calculating function
to-report calculate_score [ worker_id company_id ]
  ;;get values
  let worker_loc -1
  let worker_skills [ ]
  let worker_salary -1

  let company_loc -1
  let company_skills [ ]
  let company_salary -1

  ask worker worker_id[
    set worker_loc location
    set worker_skills skills
    set worker_salary salary
  ]

  ask company company_id[
    set company_loc location
    set company_skills skills
    set company_salary salary
  ]

  ;;scores
  let dist_score 0
  let skills_score 0
  let salary_score 0

  ;;calculate location score
  if company_loc = worker_loc [ set dist_score 1 ]

  ;;calculate skills score
  let i 0
  while [ i < 5 ][
    if item i worker_skills = item i company_skills [ set skills_score skills_score + 0.2 ]
    set i i + 1
  ]

  ;;calculate salary score
  let tmp_sal_score ( 1 - ( ( worker_salary - company_salary ) /  max list worker_salary company_salary  ) )
  set salary_score min list 1 tmp_sal_score

  ;;aggregate
  report ( dist_score + skills_score + salary_score ) / 3

end

;;hiring worker in company
to hire [ worker_id company_id ]
  let company_col red
  ask company company_id [
    set worker_list insert-item 0 worker_list worker_id
    set company_col color
  ]

  ask worker worker_id
  [
    set employer company_id
    set color company_col
    if display_links [ create-link-to company employer [ set color company_col ] ]
  ]


end

;;notice the employee on firing
to fire [ employee_id ]
  ask worker employee_id [
    set color white
    set employer -1
    register_as_job_seeker who
    ask my-links [
      die
    ]
  ]
end

;;executed at each iteration for graphic purposes
to graphic_update
  ;;on display_links change
  if  not last_display_links = display_links  [

    ifelse display_links
    ;;changed from false to true
    [
      ask workers[
        if not ( employer = -1 ) [
          let company_col red
          ask company employer [ set company_col color ]
          create-link-to company employer [ set color company_col ]
        ]
      ]
    ]
    ;;changed from true to false
    [
      ask links [
        die
      ]
    ]
    set last_display_links display_links
  ]
end
@#$#@#$#@
GRAPHICS-WINDOW
767
14
1408
656
-1
-1
6.33
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
99
0
99
1
1
1
ticks
30.0

SLIDER
9
72
188
105
U
U
0
400
200.0
50
1
unemployed
HORIZONTAL

SLIDER
9
119
187
152
V
V
0
400
200.0
50
1
vacancy
HORIZONTAL

SLIDER
14
512
248
545
quality_treshold
quality_treshold
0
1
0.5
0.01
1
NIL
HORIZONTAL

SLIDER
262
212
434
245
firing_treshold
firing_treshold
0
1
0.5
0.01
1
NIL
HORIZONTAL

SLIDER
263
262
434
295
unexpected_firing
unexpected_firing
0
1
0.1
0.01
1
NIL
HORIZONTAL

SLIDER
12
406
260
439
max_product_fluctuation
max_product_fluctuation
0
1
0.3
0.01
1
NIL
HORIZONTAL

SLIDER
10
262
248
295
unexpected_company_motivation
unexpected_company_motivation
0
1
0.1
0.01
1
NIL
HORIZONTAL

SLIDER
12
357
260
390
unexpected_worker_motivation
unexpected_worker_motivation
0
1
0.1
0.01
1
NIL
HORIZONTAL

SLIDER
13
566
248
599
exceptional_matching_bonus
exceptional_matching_bonus
0
1
0.1
0.01
1
NIL
HORIZONTAL

TEXTBOX
66
39
216
62
Global
20
0.0
1

TEXTBOX
43
177
193
202
Companies
20
0.0
1

TEXTBOX
53
323
203
348
Workers\n
20
0.0
1

TEXTBOX
20
467
222
493
Matching Agent\n
20
0.0
1

BUTTON
667
72
733
105
Setup
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
10
212
248
245
nb_companies
nb_companies
0
100
20.0
1
1
companies
HORIZONTAL

BUTTON
668
119
734
152
Run
simulate
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SWITCH
398
119
639
152
display_links
display_links
1
1
-1000

SLIDER
398
72
639
105
sqrt_nb_locations
sqrt_nb_locations
1
10
4.0
1
1
zone on each side
HORIZONTAL

SLIDER
208
119
379
152
salary_mean
salary_mean
1171
5000
1800.0
1
1
€
HORIZONTAL

SLIDER
207
72
379
105
salary_sigma
salary_sigma
0
2000
400.0
10
1
 €
HORIZONTAL

SLIDER
262
512
530
545
matches_by_round
matches_by_round
0
100
10.0
1
1
match/iteration
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
NetLogo 6.1.0
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
