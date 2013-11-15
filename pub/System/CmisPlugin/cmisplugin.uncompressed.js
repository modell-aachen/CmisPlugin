jQuery(function($) {
  $(".cmisBrowser").livequery(function() {
    var $browser = $(this);
    
    $browser.find(".cmisResults .cmisObject").hover(
      function() {
        $(this).addClass("cmisHover");
      },
      function() {
        $(this).removeClass("cmisHover");
      }
    );
  });
});
