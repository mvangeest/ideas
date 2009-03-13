<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN"
   "http://www.w3.org/TR/html4/strict.dtd">
<html>
<head>
<meta http-equiv="Content-Type" content="text/html;charset=utf-8" >

<title>OU Exercise Assistant On-line</title>
<link rel="stylesheet" type="text/css" href="/genexas/css/exas.css" >
<link rel="shortcut icon" href="/genexas/css/favicon.ico" type="image/x-icon" >
<script type="text/javascript" src="/genexas/common/javascript/prototype-1.6.0.2.js"></script> 
<script type="text/javascript" src="/genexas/common/javascript/help.js"></script>
<script type="text/javascript" src="/genexas/common/javascript/services.js"></script>
<script type="text/javascript" src="/genexas/common/javascript/communication.js"></script>
<script type="text/javascript" src="<?php print getLanguage();?>"></script>
<script type="text/javascript">var exercisekind = <?php $kind = getKind(); echo '"'.$kind.'";'; ?>var id=421;</script>
<?php if (getStudentNumber() != "") print getStudentNumber();?>
<script type="text/javascript" src="/genexas/common/javascript/init.js"></script>
<script type="text/javascript" src="/genexas/common/javascript/keyboard.js"></script>	
</head>

<h1>Exercise Assistant online</h1>
<div id="exasdiv">
<input class="menu" type="button" id="aboutButton" value="<?php print About;?>" >
<input class="menu" type="button" id="helpButton" value="<?php print Help;?>" >
<input class="menu" type="button" onclick="window.open('http://ideas.cs.uu.nl/rules/logic/PropositiontoDNF/overview.pdf','','')" value="<?php print Rules;?>" >
<input class="menu" type="button" id="generateButton" value="<?php print NewExercise;?>" >
<br class="clear" >

<div class="column left">
	<h3><?php print Exercise;?></h3>
	<div id="exercise" ></div><!-- end div exercise -->

	<h3><?php print WorkArea;?></h3>

	<textarea id="work" rows="2" cols="40" >	
	</textarea>
	<input class="minibutton" id="submitbutton" type="button" value="<?php print Submit;?>" >	
	<input class="minibutton" type="button" id="readybutton" value="<?php print Ready;?>" >
	<input class="minibutton" type="button" id="undobutton" value="<?php print Back;?>" >
	<input class="minibutton" type="button" id="forwardbutton" value="<?php print Forward;?>" >
	<br class="clear">
	<input id="derivationbutton" style="background-color: #CCCC99; float: right; display: inline; height: 20px; position: relative; right: -45px; margin-right: 0px;" type="button" value="<?php print Derivation;?>" >	
	<input class="minibutton" type="button" id="copybutton" value="<?php print Copy;?>" >
	<input id="nextbutton"  class="minibutton" type="button" value="<?php print Step;?>" >
	<input id="hintbutton" class="minibutton" type="button" value="<?php print Hint;?>" >
	
	<div id="progress">Steps<br>0</div><!-- end div progress -->
	
	<br/>
	<div align="center" width="100%"><br/><?php include("/var/www/html/genexas/common/keys.php"); ?></div>


</div><!-- end div column left -->

<div class="column right">
	<h3><?php print Feedback ?></h3>
	<div id="feedback" class="clear"><?php print Welcome;?></div><!-- end div feedback -->
	<table><tr><td>
		&nbsp;&nbsp;<input class="feedbacklabel" type="checkbox" name="feedbackchoice" id="feedbackclearchoice" checked value="chooseclear">
		<label class="feedbacklabel" for="feedbackclearchoice"><?php print ChooseClear;?></label>
<!--	</td><tr><td>
		<label class="feedbacklabel"><?php print ChooseKeep;?><input type="radio" name="feedbackchoice"  id="feedbackeepchoice" value="choosekeep" ></label> -->
	</td><td>
		<input type="button" id="clearbutton" value="<?php print Clear;?>"  style="display: none">
	</td></tr></table>
	
	<br>
       	<h3><?php print History;?></h3>
	<div id="history"></div><!-- end div history -->
	
</div><!-- end div column right -->

<div id="rules" class="helparea invisible">
<input class="helpbutton" id="closerulesButton" type="button" value="<?php print Close;?>" >
<?php rules();?>
</div><!-- end div rules -->

<div id="help" class="helparea invisible">
<input class="helpbutton"  id="closehelpButton" type="button" value="<?php print Close;?>" >
<?php help();?>
</div><!-- end div help -->

<div id="about" class="helparea invisible">
<input class="helpbutton"  id="closeaboutButton" type="button" value="<?php print Close;?>" >
<?php about();?>

</div><!-- end div about -->
</div><!-- end div exas -->
</body>
</html>
