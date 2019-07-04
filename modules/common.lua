-- Message types
msgtype_param		= hash("msgtype_param")
msgtype_trigger		= hash("msgtype_trigger")
msgtype_tag			= hash("msgtype_tag")
msgtype_check_tag	= hash("msgtype_check_tag")

-- Params
-- /Updates each frame/
param_move 			= hash("param_move") -- float [-1; 1]
param_vvel			= hash("param_vvel") -- vertical velocity

-- Triggers
-- /Eventually fired/
trigger_attack		= hash("trigger_attack")
trigger_damage		= hash("trigger_damage")
trigger_jump		= hash("trigger_jump")

-- Tags
-- /Activate/deactivate/
tag_grounded 		= hash("tag_grounded")
tag_hurt 			= hash("tag_hurt")
tag_attack 			= hash("tag_attack")