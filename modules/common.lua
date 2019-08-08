-- Message types
msgtype_param		= hash("msgtype_param")
msgtype_trigger		= hash("msgtype_trigger")
msgtype_tag			= hash("msgtype_tag")
msgtype_check_tag	= hash("msgtype_check_tag")
msgtype_input		= hash("msgtype_input")
msgtype_anim_event	= hash("msgtype_anim_event")

-- Params
-- /Updates each frame/
param_move 			= hash("param_move") -- float [-1; 1]
param_vvel			= hash("param_vvel") -- vertical velocity
param_attack_input	= hash("param_attack_input") -- true / false

-- Triggers
-- /Eventually fired/
trigger_attack		= hash("trigger_attack")
trigger_damage		= hash("trigger_damage")
trigger_jump		= hash("trigger_jump")

-- Tags
-- /Activate/deactivate/
tag_grounded 		= hash("tag_grounded")
tag_hurt 			= hash("tag_hurt")
tag_dead			= hash("tag_dead")
tag_attack 			= hash("tag_attack")

-- Input
input_left			= hash("left")
input_right			= hash("right")
input_attack		= hash("attack")
input_jump			= hash("jump")

-- Anim events
anim_started		= hash("anim_started")
anim_finished		= hash("anim_finished")
anim_interrupted	= hash("anim_interrupted")