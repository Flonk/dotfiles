{ }:
{
  yuck = ''
    (defwidget workspaces []
      (literal :content workspace))
  '';

  scss = ''
    .works { font-size: 27px; font-weight: normal; margin: 5px 0px 0px 20px; background-color: #0f0f17; }
    .0 , .01, .02, .03, .04, .05, .06,
    .011, .022, .033, .044, .055, .066 { margin: 0px 10px 0px 0px; }
    .0 { color: #3e424f; }
    .01, .02, .03, .04, .05, .06 { color: #bfc9db; }
    .011, .022, .033, .044, .055, .066 { color: #a1bdce; }
  '';
}
