var $fileContainer;
var fileLabel;
var currentFile;

function showFileVersionNotification(show) {
  if (show) {
    $(".show-on-new-file-version").each(function(i, it) {
      $(it).removeClass("hidden");
    });

    $("#refreshFileButton").addClass("text-warning");
  } else {
    $(".show-on-new-file-version").each(function(i, it) {
      $(it).addClass("hidden");
    });

    $("#refreshFileButton").removeClass("text-warning");
  }
}

function openFile(file) {
  if (!file && currentFile) {
    file = currentFile;
  } else {
    currentFile = file;
  }

  var fileContents = $fileContainer.find(".contents")[0];
  fileLabel.innerHTML = file.name;
  document.title = file.name;
  $("#refreshFileButton").removeClass("text-warning");
  showFileVersionNotification(false);
  
  $(".file-control").each(function(i, it) {
    $(it).removeClass("file-control");
  });

  if (file.type) {
    console.log("opening type", file.type);

    var mediaType = file.type.split("/")[0];

    if (mediaType == "image") {
      fileContents.innerHTML = '<img class="img-responsive center-block" src="' + file.url + '"/>';

      $.ajax({
        method: "head",
        url: file.url,
        complete: function(xhr) {
          renderLastUpdateTime("fileUpdateTime", new Date(xhr.getResponseHeader("Last-Modified")));
        }
      });
    } else /*if (mediaType == "text")*/ {
      fileContents.innerHTML = "";

      $fileContainer.addClass("loading");

      $.ajax({
        method: "get",
        url: file.url,
        dataType: "text",
        mimeType: "plain/text"
      })
      .done(function(data, status, xhr) {
        renderLastUpdateTime("fileUpdateTime", new Date(xhr.getResponseHeader("Last-Modified")));

        fileContents.innerHTML = data.replace(/&/g, "&amp;")
          .replace(/>/g, "&gt;")
          .replace(/</g, "&lt;");

        fileContents.className = "contents highlight lang-" + file.ext;

        hljs.highlightBlock(fileContents);
      })
      .fail(function(_, err) {
        alert(err);
      })
      .always(function() {
        $fileContainer.removeClass("loading");
      });
    }
  }
}
