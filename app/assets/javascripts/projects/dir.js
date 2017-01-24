var $dir;
var activeItem; //currently selected dir item

function showDirUpdatedNotification(show) {
  if (show) {
    $(".show-on-dir-update").each(function(i, it) {
      $(it).removeClass("hidden");
    });

    $("#refreshDirButton").addClass("text-warning");
  } else {
    $(".show-on-dir-update").each(function(i, it) {
      $(it).addClass("hidden");
    });

    $("#refreshDirButton").removeClass("text-warning");
  }
}

function fileEquals(a, b) {
  return a && b && a.dir == b.dir && a.name == b.name;
}

function hideChildren(elem, hide) {
  var $elem = $(elem);

  elem.files.forEach(function(it) {
    var $it = $(it);

    if (hide) {
      $it.addClass("hidden");
    } else {
      $it.removeClass("hidden");
    }

    if (it.files && (hide || $it.hasClass("dir-open"))) {
      hideChildren(it, hide);
    }
  });
}

function toggleDir(ev) {
  var elem = this;
  var $elem = $(elem)
  var $icon = $elem.find(".glyphicon");

  var isOpen = $elem.hasClass("dir-open");

  if (isOpen) {
    $elem.removeClass("dir-open");

    $icon.addClass("glyphicon-folder-close");
    $icon.removeClass("glyphicon-folder-open");
  } else {
    $elem.addClass("dir-open");

    $icon.addClass("glyphicon-folder-open");
    $icon.removeClass("glyphicon-folder-close");
  }

  hideChildren(elem, isOpen);
}

function selectDirItem(li) {
  if (activeItem) {
    $(activeItem).removeClass("active");
  }
  li.className += " active";
  activeItem = li;
}

function addDirEntry(it, container) {
  var li = document.createElement("a");
  li.className = "list-group-item clickable";
  li.id = "p-" + (it.dir ? (it.dir + "/") : "") + it.name;

  var label = document.createElement("span");
  label.style.paddingLeft = (li.id.match(/\//g) || []).length * 2 + "em";

  if (it.url) {
    li.onclick = function() {
      openFile(it);

      selectDirItem(li);
    }
  } else {
    li.className += " dir-open";
    li.onclick = toggleDir.bind(li);
    li.files = [];

    label.innerHTML = '<i class="glyphicon glyphicon-folder-open file-icon"></i>';
  }
  
  label.innerHTML += it.name;

  if (it.dir) {
    var itsParent = document.getElementById("p-" + it.dir);

    if (!itsParent) {
      tokenList = it.dir.split("/");

      itsParent = addDirEntry({
        name: tokenList[tokenList.length -1],
        dir: tokenList.slice(0, tokenList.length -1).join("/"),
      }, container);
    }

    itsParent.files.push(li);
  }

  li.appendChild(label);
  container.appendChild(li);

  return li;
}

function listFiles(shownFile) {
  $dir.addClass("loading");
  var container = $dir.find(".contents")[0];

  showDirUpdatedNotification(false);

  $.ajax({
    method: "get",
    url: "/projects/" + PROJECT_ID + "/dir"
  })
  .done(function(list) {
    container.innerHTML = "";

    if (list.length == 0) {
      container.innerHTML = "empty";
    }

    list.forEach(function(file) {
      addDirEntry(file, container);
      console.log(file)
    });

    if (shownFile) {
      var matches = list.filter(function(it) {
        return shownFile == ((it.dir ? (it.dir + "/") : "") + it.name);
      });

      if (matches.length < 1) {
        confirm("The file " + shownFile + " couldn't be found.\nIt may have been deleted");
      } else if (matches.length > 1) {
        alert("multiple matching files found. This must be an error.");
      } else {
        openFile(matches[0]);

	selectDirItem(document.getElementById("p-" + shownFile));
      }
    }
  })
  .fail(function(err) {
    if (err.status >= 500) {
      //TODO notify me about this error
      alert("Sorry...\n\nA server error has occured. The developer has been notified and this issue will be fixed shortly.");
    } else {
      console.error("an error occured.")
      console.error(err.responseText);
    };
  })
  .always(function() {
    $dir.removeClass("loading");
  });
}
