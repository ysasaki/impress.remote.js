/**
 * impress.remote.client.js
 *
 * MIT Licensed.
 *
 * Dependencies
 *  - impress.js
 *  - jQuery
 *  - jQuery ScrollTo.
 *
 * Copyright 2012 Yoshihiro Sasaki (@aloelight)
 */
(function(document, window){
    var host = document.location.host;
    var ua = navigator.userAgent.toLowerCase();
    var ws = new WebSocket('ws://'+host);
    var isController = ua.search(/(iphone)|(ipod)|(ipad)|(android)/) > 0;

    if ( isController ) {
        // iPhone, Android
        jQuery(function($){
            $('.fallback-message').hide();
            var $steps = $('.step') , positions = [];

            // getting offset of all steps to scroll in controller's view
            $steps.each(function() {
                positions.push(parseInt($(this).offset()['top'],10));
            });

            var stepLength = positions.length;
            function scroll(direction) {
                var i, scroll;
                var currentOffset = $(window).scrollTop();

                for(i = 0; i < stepLength; i++) {
                    if (direction == 'next' && positions[i] > currentOffset + positions[0]) {
                        scroll = $steps.get(i);
                        break;
                    }
                    if (direction == 'previous' && i > 0 && positions[i] >= currentOffset) {
                        scroll = $steps.get(i-1);
                        break;
                    }
                }

                if (scroll) {
                    ws.send(direction);
                    $.scrollTo(scroll, {
                        duration: 250
                    });
                }
                return false;
            }

            var width = $steps.first().width()
                , start = {x:0,y:0};

            $steps.bind('touchstart', function() {
                var t = event.targetTouches[0];
                start = { x: t.pageX, y: t.pageY };
            });
            $steps.bind('touchmove', function() {
                start = {x:0,y:0};
            });
            $steps.bind('touchend', function() {
                if ( start.x == 0 ) {
                    return;
                }
                if ( start.x >= (width/2) ) {
                    scroll('next');
                }
                else {
                    scroll('previous');
                }
            });
        });
    }
    else {
        // PC
        ws.onmessage = function(e){
            console.log(e.data);
            switch( e.data ) {
                case 'next':
                    selectNext();
                    break;
                case 'previous':
                    selectPrev();
                    break;
            }
        };
    }
})(document, window);
