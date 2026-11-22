extends Node

var weak = 1.4
var resist = 0.6

var affinity = {
	"red": {
		"red": 1, 
		"blue": weak, 
		"green": resist, 
		"yellow": 1, 
		"white": 1, 
		"black": 1, 
		"none": 1
		}, 

	"blue": {
		"red": resist, 
		"blue": 1, 
		"green": weak, 
		"yellow": 1, 
		"white": 1, 
		"black": 1, 
		"none": 1
		}, 

	"green": {
		"red": weak, 
		"blue": resist, 
		"green": 1, 
		"yellow": 1, 
		"white": 1, 
		"black": 1, 
		"none": 1
		}, 

	"yellow": {
		"red": 1, 
		"blue": 1, 
		"green": 1, 
		"yellow": 1, 
		"white": resist, 
		"black": weak, 
		"none": 1
		}, 

	"white": {
		"red": 1, 
		"blue": 1, 
		"green": 1, 
		"yellow": weak, 
		"white": 1, 
		"black": resist, 
		"none": 1
		}, 

	"black": {
		"red": 1, 
		"blue": 1, 
		"green": 1, 
		"yellow": resist, 
		"white": weak, 
		"black": 1, 
		"none": 1
		}, 
}

var colors = {
	"red": ["#961a1b", "#e62829", "#ef7374", "#b37f7f"], 
	"blue": ["#1b539b", "#2980ef", "#74acf5", "#4a6c96"], 
	"green": ["#29691b", "#3fa129", "#82c274", "#64825d"], 
	"yellow": ["#a37d00", "#fac000", "#fcd659", "#b4ab89"], 
	"white": ["#676967", "#9fa19f", "#c1c2c1", "#909090"], 
	"black": ["#442c3b", "#614c59", "#9c8194", "#4b3a42"], 
	"none": ["#ffffff", "#ffffff", "#000000", "#ffffff"], 

	"ap": "#d81818", 
	"pp": "#1858b8", 
}
