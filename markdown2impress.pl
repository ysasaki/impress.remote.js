#!/usr/bin/env perl

use strict;
use Cwd;
use Getopt::Long;
use Data::Section::Simple qw( get_data_section );
use File::Path qw( make_path );
use File::Spec;
use Path::Class;
use Text::Markdown qw( markdown );
use Text::Xslate qw( mark_raw );

my %opts = (
    width      => 1200,
    height     => 800,
    max_column => 5,
    outputdir  => getcwd(),
);

GetOptions(
    'width=i'     => \$opts{ width },
    'height=i'    => \$opts{ height },
    'column=i'    => \$opts{ max_column },
    'outputdir=s' => \$opts{ outputdir },
);

my $SectionRe = qr{(.+[ \t]*\n[-=]+[ \t]*\n*(?:(?!.+[ \t]*\n[-=]+[ \t]*\n*)(?:.|\n))*)};

$opts{ outputdir } = File::Spec->canonpath( $opts{ outputdir } );
output_static_files( $opts{ outputdir } );

my $outputfile = 'index.html';
$outputfile = File::Spec->catfile( $opts{ outputdir }, $outputfile );

my $mdfile = $ARGV[0] or die;
my $content = parse_markdown( join '', file( $mdfile )->slurp );

my $index_html = get_data_section( 'index.html' );
my $tx = Text::Xslate->new;
my $output = $tx->render_string( $index_html, {
    content => mark_raw( $content ),
} );
my $outputfile_fh = file( $outputfile )->open( 'w' ) or die $!;
print $outputfile_fh $output;
close $outputfile_fh;

sub parse_markdown {
    my $md = shift;
    my $content;
    my @sections;
    while ( $md =~ /$SectionRe/g ) {
        push @sections, $1;
    }
    my $bored = 1;
    my $x = 0;
    my $y = 0;
    my $current_column = 0;
    for my $section ( @sections ) {
        my %attrs;
        $attrs{ class } = 'step slide'; # default
        while ( $section =~ /^<!\-{2,}\s*([^\s]+)\s*\-{2,}>/gm ) {
            my $attr = $1;
            if ( $attr =~ /(.+)="?([^"]+)?"?/ ) {
                $attrs{ $1 } = $attrs{ $1 } ? [ $attrs{ $1 }, $2 ] : $2;
            }
        }
        if ( !defined $attrs{ id } && $x == 0 && $y == 0 ) {
            $attrs{ id } = 'title'; # for first presentation
        }
        unless ( defined $attrs{ 'data-x' } ) {
            $attrs{ 'data-x' } = $x;
            $x += $opts{ width };
        }
        unless ( defined $attrs{ 'data-y' } ) {
            $attrs{ 'data-y' } = $y;
            $current_column++;
            if ( $current_column >= $opts{ max_column } ) {
                $x = 0;
                $y += $opts{ height };
                $current_column = 0;
            }
        }
        my $attrs = join ' ', map {
            if ( ref $attrs{ $_ } eq 'ARRAY' ) {
                sprintf '%s="%s"', $_, join ' ', @{ $attrs{$_} };
            }
            else {
                sprintf '%s="%s"', $_, $attrs{$_};
            }
        } keys %attrs;
        $content .= sprintf <<'HTML', $attrs, markdown( $section );
<div %s>
%s
</div>
HTML
        ;
        $bored = undef;
    }
    return $content;
}

sub output_static_files {
    my $dir = shift;

    my $jsdir = File::Spec->catfile( $dir, 'js' );
    unless ( -d $jsdir ) {
        make_path( $jsdir );
    }

    my $cssdir = File::Spec->catfile( $dir, 'css' );
    unless ( -d $cssdir ) {
        make_path( $cssdir );
    }

    _output_static_files( $dir, qw/
        impress.remote.js
        impress.remote.server.js
        /
    );
    _output_static_files( $jsdir, qw/
        impress.js
        impress.remote.client.js
        jquery.scrollTo-min.js
        /
    );
    _output_static_files( $cssdir, qw/impress.css/ );
}

sub _output_static_files {
    my ( $dir, @files ) = @_;

    for (@files) {
        my $file = file( File::Spec->catfile( $dir, $_ ) );
        unless ( -f $file ) {
            my $data = get_data_section($_);
            my $fh = $file->openw;
            print $fh $data;
            $fh->close;
        }
    }
}

__DATA__

@@ index.html
<!doctype html>
<html>
<head>
    <meta charset="utf-8" />
    <meta name="viewport" content="user-scalable=no">
    <title><: $title :></title>
    <link href="http://fonts.googleapis.com/css?family=Open+Sans:regular,semibold,italic,italicsemibold|PT+Sans:400,700,400italic,700italic|PT+Serif:400,700,400italic,700italic" rel="stylesheet" />
    <link href="css/impress.css" rel="stylesheet" />
    <link rel="stylesheet" href="google-code-prettify/prettify.css" />
</head>
<body>
<div id="impress" class="impress-not-supported">
    <div class="fallback-message">
        <p>Your browser <b>doesn't support the features required</b> by impress.js, so you are presented with a simplified version of this presentation.</p>
        <p>For the best experience please use the latest <b>Chrome</b> or <b>Safari</b> browser. Firefox 10 (to be released soon) will also handle it.</p>
    </div>

<: $content :>

    <div id="overview" class="step" data-x="3000" data-y="1500" data-scale="10">
    </div>

</div>

<div class="hint">
    <p>Use a spacebar or arrow keys to navigate</p>
</div>
<script>
if ("ontouchstart" in document.documentElement) { 
    document.querySelector(".hint").innerHTML = "<p>Tap on the left or right to navigate</p>";
}
</script>
<script src="js/impress.js"></script>
<script src="http://ajax.googleapis.com/ajax/libs/jquery/1.7.2/jquery.min.js"></script>
<script src="js/jquery.scrollTo-min.js"></script>
<script src="js/impress.remote.client.js"></script>
<script src="google-code-prettify/prettify.js" type="text/javascript"></script>
<script>
$(function(){
    $('code').addClass('prettyprint');
    prettyPrint();
});
</script>
</body>
</html>

@@ impress.js

/**
 * impress.js
 *
 * impress.js is a presentation tool based on the power of CSS3 transforms and transitions
 * in modern browsers and inspired by the idea behind prezi.com.
 *
 * MIT Licensed.
 *
 * Copyright 2011 Bartek Szopka (@bartaz)
 */

var selectNext, selectPrev;
(function ( document, window ) {
    'use strict';

    // HELPER FUNCTIONS
    
    var pfx = (function () {

        var style = document.createElement('dummy').style,
            prefixes = 'Webkit Moz O ms Khtml'.split(' '),
            memory = {};
            
        return function ( prop ) {
            if ( typeof memory[ prop ] === "undefined" ) {

                var ucProp  = prop.charAt(0).toUpperCase() + prop.substr(1),
                    props   = (prop + ' ' + prefixes.join(ucProp + ' ') + ucProp).split(' ');

                memory[ prop ] = null;
                for ( var i in props ) {
                    if ( style[ props[i] ] !== undefined ) {
                        memory[ prop ] = props[i];
                        break;
                    }
                }

            }

            return memory[ prop ];
        }

    })();

    var arrayify = function ( a ) {
        return [].slice.call( a );
    };
    
    var css = function ( el, props ) {
        var key, pkey;
        for ( key in props ) {
            if ( props.hasOwnProperty(key) ) {
                pkey = pfx(key);
                if ( pkey != null ) {
                    el.style[pkey] = props[key];
                }
            }
        }
        return el;
    }
    
    var byId = function ( id ) {
        return document.getElementById(id);
    }
    
    var $ = function ( selector, context ) {
        context = context || document;
        return context.querySelector(selector);
    };
    
    var $$ = function ( selector, context ) {
        context = context || document;
        return arrayify( context.querySelectorAll(selector) );
    };
    
    var translate = function ( t ) {
        return " translate3d(" + t.x + "px," + t.y + "px," + t.z + "px) ";
    };
    
    var rotate = function ( r, revert ) {
        var rX = " rotateX(" + r.x + "deg) ",
            rY = " rotateY(" + r.y + "deg) ",
            rZ = " rotateZ(" + r.z + "deg) ";
        
        return revert ? rZ+rY+rX : rX+rY+rZ;
    };
    
    var scale = function ( s ) {
        return " scale(" + s + ") ";
    }
    
    // CHECK SUPPORT
    
    var ua = navigator.userAgent.toLowerCase();
    var impressSupported = ( pfx("perspective") != null ) &&
                           ( ua.search(/(iphone)|(ipod)|(ipad)|(android)/) == -1 );
    
    // DOM ELEMENTS
    
    var impress = byId("impress");
    
    if (!impressSupported) {
        impress.className = "impress-not-supported";
        return;
    } else {
        impress.className = "";
    }
    
    var canvas = document.createElement("div");
    canvas.className = "canvas";
    
    arrayify( impress.childNodes ).forEach(function ( el ) {
        canvas.appendChild( el );
    });
    impress.appendChild(canvas);
    
    var steps = $$(".step", impress);
    
    // SETUP
    // set initial values and defaults
    
    document.documentElement.style.height = "100%";
    
    css(document.body, {
        height: "100%",
        overflow: "hidden"
    });

    var props = {
        position: "absolute",
        transformOrigin: "top left",
        transition: "all 0s ease-in-out",
        transformStyle: "preserve-3d"
    }
    
    css(impress, props);
    css(impress, {
        top: "50%",
        left: "50%",
        perspective: "1000px"
    });
    css(canvas, props);
    
    var current = {
        translate: { x: 0, y: 0, z: 0 },
        rotate:    { x: 0, y: 0, z: 0 },
        scale:     1
    };

    steps.forEach(function ( el, idx ) {
        var data = el.dataset,
            step = {
                translate: {
                    x: data.x || 0,
                    y: data.y || 0,
                    z: data.z || 0
                },
                rotate: {
                    x: data.rotateX || 0,
                    y: data.rotateY || 0,
                    z: data.rotateZ || data.rotate || 0
                },
                scale: data.scale || 1
            };
        
        el.stepData = step;
        
        if ( !el.id ) {
            el.id = "step-" + (idx + 1);
        }
        
        css(el, {
            position: "absolute",
            transform: "translate(-50%,-50%)" +
                       translate(step.translate) +
                       rotate(step.rotate) +
                       scale(step.scale),
            transformStyle: "preserve-3d"
        });
        
    });

    // making given step active

    var active = null;
    var hashTimeout = null;
    
    var select = function ( el ) {
        if ( !el || !el.stepData || el == active) {
            // selected element is not defined as step or is already active
            return false;
        }
        
        // Sometimes it's possible to trigger focus on first link with some keyboard action.
        // Browser in such a case tries to scroll the page to make this element visible
        // (even that body overflow is set to hidden) and it breaks our careful positioning.
        //
        // So, as a lousy (and lazy) workaround we will make the page scroll back to the top
        // whenever slide is selected
        //
        // If you are reading this and know any better way to handle it, I'll be glad to hear about it!
        window.scrollTo(0, 0);
        
        var step = el.stepData;
        
        if ( active ) {
            active.classList.remove("active");
        }
        el.classList.add("active");
        
        impress.className = "step-" + el.id;
        
        // `#/step-id` is used instead of `#step-id` to prevent default browser
        // scrolling to element in hash
        //
        // and it has to be set after animation finishes, because in chrome it
        // causes transtion being laggy
        window.clearTimeout( hashTimeout );
        hashTimeout = window.setTimeout(function () {
            window.location.hash = "#/" + el.id;
        }, 1000);
        
        var target = {
            rotate: {
                x: -parseInt(step.rotate.x, 10),
                y: -parseInt(step.rotate.y, 10),
                z: -parseInt(step.rotate.z, 10)
            },
            translate: {
                x: -step.translate.x,
                y: -step.translate.y,
                z: -step.translate.z
            },
            scale: 1 / parseFloat(step.scale)
        };
        
        // check if the transition is zooming in or not
        var zoomin = target.scale >= current.scale;
        
        // if presentation starts (nothing is active yet)
        // don't animate (set duration to 0)
        var duration = (active) ? "600ms" : "0";
        
        css(impress, {
            // to keep the perspective look similar for different scales
            // we need to 'scale' the perspective, too
            perspective: step.scale * 1000 + "px",
            transform: scale(target.scale),
            transitionDuration: duration,
            transitionDelay: (zoomin ? "500ms" : "0ms")
        });
        
        css(canvas, {
            transform: rotate(target.rotate, true) + translate(target.translate),
            transitionDuration: duration,
            transitionDelay: (zoomin ? "0ms" : "500ms")
        });
        
        current = target;
        active = el;
        
        return el;
    };
    
    selectPrev = function () {
        var prev = steps.indexOf( active ) - 1;
        prev = prev >= 0 ? steps[ prev ] : steps[ steps.length-1 ];
        
        return select(prev);
    };
    
    selectNext = function () {
        var next = steps.indexOf( active ) + 1;
        next = next < steps.length ? steps[ next ] : steps[ 0 ];
        
        return select(next);
    };
    
    // EVENTS
    
    document.addEventListener("keydown", function ( event ) {
        if ( event.keyCode == 9 || ( event.keyCode >= 32 && event.keyCode <= 34 ) || (event.keyCode >= 37 && event.keyCode <= 40) ) {
            switch( event.keyCode ) {
                case 33: ; // pg up
                case 37: ; // left
                case 38:   // up
                         selectPrev();
                         break;
                case 9:  ; // tab
                case 32: ; // space
                case 34: ; // pg down
                case 39: ; // right
                case 40:   // down
                         selectNext();
                         break;
            }
            
            event.preventDefault();
        }
    }, false);

    document.addEventListener("click", function ( event ) {
        // event delegation with "bubbling"
        // check if event target (or any of its parents is a link or a step)
        var target = event.target;
        while ( (target.tagName != "A") &&
                (!target.stepData) &&
                (target != document.body) ) {
            target = target.parentNode;
        }
        
        if ( target.tagName == "A" ) {
            var href = target.getAttribute("href");
            
            // if it's a link to presentation step, target this step
            if ( href && href[0] == '#' ) {
                target = byId( href.slice(1) );
            }
        }
        
        if ( select(target) ) {
            event.preventDefault();
        }
    }, false);
    
    var getElementFromUrl = function () {
        // get id from url # by removing `#` or `#/` from the beginning,
        // so both "fallback" `#slide-id` and "enhanced" `#/slide-id` will work
        return byId( window.location.hash.replace(/^#\/?/,"") );
    }
    
    window.addEventListener("hashchange", function () {
        select( getElementFromUrl() );
    }, false);
    
    // START 
    // by selecting step defined in url or first step of the presentation
    select(getElementFromUrl() || steps[0]);

})(document, window);

@@ impress.css

/**
 * This is a stylesheet for a demo presentation for impress.js
 * 
 * It is not meant to be a part of impress.js and is not required by impress.js.
 * I expect that anyone creating a presentation for impress.js would create their own
 * set of styles.
 */


/* http://meyerweb.com/eric/tools/css/reset/ 
   v2.0 | 20110126
   License: none (public domain)
*/

html, body, div, span, applet, object, iframe,
h1, h2, h3, h4, h5, h6, p, blockquote, pre,
a, abbr, acronym, address, big, cite, code,
del, dfn, em, img, ins, kbd, q, s, samp,
small, strike, strong, sub, sup, tt, var,
b, u, i, center,
dl, dt, dd, ol, ul, li,
fieldset, form, label, legend,
table, caption, tbody, tfoot, thead, tr, th, td,
article, aside, canvas, details, embed, 
figure, figcaption, footer, header, hgroup, 
menu, nav, output, ruby, section, summary,
time, mark, audio, video {
    margin: 0;
    padding: 0;
    border: 0;
    font-size: 100%;
    font: inherit;
    vertical-align: baseline;
}

/* HTML5 display-role reset for older browsers */
article, aside, details, figcaption, figure, 
footer, header, hgroup, menu, nav, section {
    display: block;
}
body {
    line-height: 1;
}
ol, ul {
    list-style: none;
}
blockquote, q {
    quotes: none;
}
blockquote:before, blockquote:after,
q:before, q:after {
    content: '';
    content: none;
}

table {
    border-collapse: collapse;
    border-spacing: 0;
}


body {
    font-family: 'PT Sans', sans-serif;
    
    min-height: 740px;

    background: #86aecc;
    background: -moz-linear-gradient(top,  #86aecc 0%, #d5e5ef 100%);
    background: -webkit-gradient(linear, left top, left bottom, color-stop(0%,#86aecc), color-stop(100%,#d5e5ef));
    background: -webkit-linear-gradient(top,  #86aecc 0%,#d5e5ef 100%);
    background: -o-linear-gradient(top,  #86aecc 0%,#d5e5ef 100%);
    background: -ms-linear-gradient(top,  #86aecc 0%,#d5e5ef 100%);
    background: linear-gradient(top,  #86aecc 0%,#d5e5ef 100%);
    filter: progid:DXImageTransform.Microsoft.gradient( startColorstr='#86aecc', endColorstr='#d5e5ef',GradientType=0 );

    -webkit-font-smoothing: antialiased;
}

b, strong { font-weight: bold }
i, em { font-style: italic}

a {
    color: inherit;
    text-decoration: none;
    padding: 0 0.1em;
    background: rgba(255,255,255,0.5);
    text-shadow: -1px -1px 2px rgba(100,100,100,0.9);
    border-radius: 0.2em;
    
    -webkit-transition: 0.5s;
    -moz-transition:    0.5s;
    -ms-transition:     0.5s;
    -o-transition:      0.5s;
    transition:         0.5s;
}

a:hover {
    background: rgba(255,255,255,1);
    text-shadow: -1px -1px 2px rgba(100,100,100,0.5);
}

/* enable clicking on elements 'hiding' behind body in 3D */
body     { pointer-events: none; }
#impress { pointer-events: auto; }

/* COMMON STEP STYLES */

.step {
    width: 900px;
    padding: 40px;

    -webkit-box-sizing: border-box;
    -moz-box-sizing:    border-box;
    -ms-box-sizing:     border-box;
    -o-box-sizing:      border-box;
    box-sizing:         border-box;

    font-family: 'PT Serif', georgia, serif;

    font-size: 30px;
    line-height: 1.5;
}

/* fade out inactive slides */

.step {
    -webkit-transition: opacity 1s;
    -moz-transition:    opacity 1s;
    -ms-transition:     opacity 1s;
    -o-transition:      opacity 1s;
    transition:         opacity 1s;
}

.step:not(.active) {
    opacity: 0.3;
}

.step h1 {
    font-size: 80px;
    line-height: 1.2em;
    padding-bottom: 20px;
}

.step h2 {
    font-size: 60px;
    line-height: 1.2em;
    padding-bottom: 20px;
}

.step h3 {
    font-size: 40px;
    line-height: 1.2em;
    padding-bottom: 20px;
}

.step ul {
    list-style: circle;
    padding-left: 30px;
}

.step ol {
    list-style: decimal;
    padding-left: 30px;
}

.step pre {
    overflow: auto;
    white-space: pre-wrap;
    word-wrap: break-word;
    background-color: #ffffff;
    color: #000000;
    padding: 5px;
    border-radius: 10px;
    margin: 15px 0;
}

.step code {
    font-family: monospace;
    font-size: 1em;
    line-height: 1.2;
}

/* STEP SPECIFIC STYLES */

/* hint on the first slide */

.hint {
    position: fixed;
    left: 0;
    right: 0;
    bottom: 200px;
    
    background: rgba(0,0,0,0.5);
    color: #EEE;
    text-align: center;
    
    font-size: 50px;
    padding: 20px;
    
    z-index: 100;
    
    opacity: 0;
    
    -webkit-transform: translateY(400px);
    -moz-transform:    translateY(400px);
    -ms-transform:     translateY(400px);
    -o-transform:      translateY(400px);
    transform:         translateY(400px);

    -webkit-transition: opacity 1s, -webkit-transform 0.5s 1s;
    -moz-transition:    opacity 1s,    -moz-transform 0.5s 1s;
    -ms-transition:     opacity 1s,     -ms-transform 0.5s 1s;
    -o-transition:      opacity 1s,      -o-transform 0.5s 1s;
    transition:         opacity 1s,         transform 0.5s 1s;
}

.step-bored + .hint {
    opacity: 1;
    
    -webkit-transition: opacity 1s 5s, -webkit-transform 0.5s;
    -moz-transition:    opacity 1s 5s,    -moz-transform 0.5s;
    -ms-transition:     opacity 1s 5s,     -ms-transform 0.5s;
    -o-transition:      opacity 1s 5s,      -o-transform 0.5s;
    transition:         opacity 1s 5s,         transform 0.5s;
    
    -webkit-transform: translateY(0px);
    -moz-transform:    translateY(0px);
    -ms-transform:     translateY(0px);
    -o-transform:      translateY(0px);
    transform:         translateY(0px);
}

/* impress.js title */

#title {
    padding: 0;
}

#title .try {
    font-size: 64px;
    position: absolute;
    top: -0.5em;
    left: 1.5em;
    
    -webkit-transform: translateZ(20px);
    -moz-transform:    translateZ(20px);
    -ms-transform:     translateZ(20px);
    -o-transform:      translateZ(20px);
    transform:         translateZ(20px);
}

#title h1 {
    font-size: 80px;
    position: absolute;
    top: 33%;
    left: 5%;
    
    -webkit-transform: translateZ(50px);
    -moz-transform:    translateZ(50px);
    -ms-transform:     translateZ(50px);
    -o-transform:      translateZ(50px);
    transform:         translateZ(50px);
}

#title p {
    position: absolute;
    top: 80%;
    left: 50%;
    text-align: right;
}

#title .footnote {
    font-size: 32px;
}

/* big thoughts */

#big {
    width: 600px;
    text-align: center;
    font-size: 60px;
    line-height: 1;
}

#big b {
    display: block;
    font-size: 250px;
    line-height: 250px;
}

#big .thoughts {
    font-size: 90px;
    line-height: 150px;
}

/* tiny ideas */

#tiny {
    width: 500px;
    text-align: center;
}

#ing {
    width: 500px;
}

#ing b {
    display: inline-block;
    -webkit-transition: 0.5s;
    -moz-transition:    0.5s;
    -ms-transition:     0.5s;
    -o-transition:      0.5s;
    transition:         0.5s;
}

#ing.active .positioning {
    -webkit-transform: translateY(-10px);
    -moz-transform:    translateY(-10px);
    -ms-transform:     translateY(-10px);
    -o-transform:      translateY(-10px);
    transform:         translateY(-10px);

    -webkit-transition-delay: 1.5s;
    -moz-transition-delay:    1.5s;
    -ms-transition-delay:     1.5s;
    -o-transition-delay:      1.5s;
    transition-delay:         1.5s;
}

#ing.active .rotating {
    -webkit-transform: rotate(-10deg);
    -moz-transform:    rotate(-10deg);
    -ms-transform:     rotate(-10deg);
    -o-transform:      rotate(-10deg);
    transform:         rotate(-10deg);

    -webkit-transition-delay: 1.75s;
    -moz-transition-delay:    1.75s;
    -ms-transition-delay:     1.75s;
    -o-transition-delay:      1.75s;
    transition-delay:         1.75s;
}

#ing.active .scaling {
    -webkit-transform: scale(0.7);
    -moz-transform:    scale(0.7);
    -ms-transform:     scale(0.7);
    -o-transform:      scale(0.7);
    transform:         scale(0.7);

    -webkit-transition-delay: 2s;
    -moz-transition-delay:    2s;
    -ms-transition-delay:     2s;
    -o-transition-delay:      2s;
    transition-delay:         2s;

}

/* imagination */

#imagination {
    width: 600px;
}

#imagination .imagination {
    font-size: 78px;
}

/* it's in 3D */

#its-in-3d p {
    -webkit-transform-style: preserve-3d;
    -moz-transform-style:    preserve-3d; /* Y U need this Firefox?! */
    -ms-transform-style:     preserve-3d;
    -o-transform-style:      preserve-3d;
    transform-style:         preserve-3d;
}

#its-in-3d span,
#its-in-3d b {
    display: inline-block;
    -webkit-transform: translateZ(40px);
    -moz-transform:    translateZ(40px);
    -ms-transform:     translateZ(40px);
    -o-transform:      translateZ(40px);
     transform:        translateZ(40px);
            
    -webkit-transition: 0.5s;
    -moz-transition:    0.5s;
    -ms-transition:     0.5s;
    -o-transition:      0.5s;
    transition:         0.5s;
}

#its-in-3d .have {
    -webkit-transform: translateZ(-40px);
    -moz-transform:    translateZ(-40px);
    -ms-transform:     translateZ(-40px);
    -o-transform:      translateZ(-40px);
    transform:         translateZ(-40px);
}

#its-in-3d .you {
    -webkit-transform: translateZ(20px);
    -moz-transform:    translateZ(20px);
    -ms-transform:     translateZ(20px);
    -o-transform:      translateZ(20px);
    transform:         translateZ(20px);
}

#its-in-3d .noticed {
    -webkit-transform: translateZ(-40px);
    -moz-transform:    translateZ(-40px);
    -ms-transform:     translateZ(-40px);
    -o-transform:      translateZ(-40px);
    transform:         translateZ(-40px);
}

#its-in-3d .its {
    -webkit-transform: translateZ(60px);
    -moz-transform:    translateZ(60px);
    -ms-transform:     translateZ(60px);
    -o-transform:      translateZ(60px);
    transform:         translateZ(60px);
}

#its-in-3d .in {
    -webkit-transform: translateZ(-10px);
    -moz-transform:    translateZ(-10px);
    -ms-transform:     translateZ(-10px);
    -o-transform:      translateZ(-10px);
    transform:         translateZ(-10px);
}

#its-in-3d .footnote {
    font-size: 32px;

    -webkit-transform: translateZ(-10px);
    -moz-transform:    translateZ(-10px);
    -ms-transform:     translateZ(-10px);
    -o-transform:      translateZ(-10px);
    transform:         translateZ(-10px);
}

#its-in-3d.active span,
#its-in-3d.active b {
    -webkit-transform: translateZ(0px);
    -moz-transform:    translateZ(0px);
    -ms-transform:     translateZ(0px);
    -o-transform:      translateZ(0px);
    transform:         translateZ(0px);
    
    -webkit-transition-delay: 1s;
    -moz-transition-delay:    1s;
    -ms-transition-delay:     1s;
    -o-transition-delay:      1s;
    transition-delay:         1s;
}

/* overview step */

#overview {
    z-index: -1;
    padding: 0;
}

/* on overview step everything is visible */

#impress.step-overview .step {
    opacity: 1;
    cursor: pointer;
}

/*
 * SLIDE STEP STYLES
 *
 * inspired by: http://html5slides.googlecode.com/svn/trunk/styles.css
 *
 * ;)
 */

.slide {
    display: block;

    width: 900px;
    height: 700px;

    padding: 40px 60px;

    border-radius: 10px;

    background-color: white;

    box-shadow: 0 2px 6px rgba(0, 0, 0, .1);
    border: 1px solid rgba(0, 0, 0, .3);

    font-family: 'Open Sans', Arial, sans-serif;

    color: rgb(102, 102, 102);
    text-shadow: 0 2px 2px rgba(0, 0, 0, .1);

    font-size: 30px;
    line-height: 36px;

    letter-spacing: -1px;
}

.slide q {
    display: block;
    font-size: 50px;
    line-height: 72px;

    margin-top: 100px;
}

.slide q strong {
    white-space: nowrap;
}


/* IMPRESS NOT SUPPORTED STYLES */

.fallback-message {
    font-family: sans-serif;
    line-height: 1.3;
    
    display: none;
    width: 780px;
    padding: 10px 10px 0;
    margin: 20px auto;

    border-radius: 10px;
    border: 1px solid #E4C652;
    background: #EEDC94;
}

.fallback-message p {
    margin-bottom: 10px;
}

.impress-not-supported .step {
    position: relative;
    opacity: 1;
    margin: 20px auto;
}

.impress-not-supported .fallback-message {
    display: block;
}

@@ impress.remote.js

/**
 * impress.remote.js
 *
 * MIT Licensed.
 *
 * Copyright 2012 Yoshihiro Sasaki (@aloelight)
 */
var util = require('util')
    , express = require('express')
    , WebSocketServer = require('ws').Server;

function Remote(options, callback) {
    var server = express.createServer();
    server.configure(function(){
        server.use(express.static(__dirname));
    });
    WebSocketServer.call(this, {server:server}, callback);
    var self = this;
    this.on('connection', function(ws) {
        console.log('Client connected');
        ws.on('message', function(message) {
            console.log('received: %s', message);
            self.broadcast(ws, message);
        });
        ws.send('Connected to impress.remote.js');
    });
    server.listen(options.port, options.host);
    return this;
};
util.inherits(Remote, WebSocketServer);

Remote.prototype.broadcast = function(sender, message) {
    var len = this.clients.length;
    for ( var i = 0; i<len; i++ ) {
        var c = this.clients[i];
        if ( c === sender ) {
            c.send('broadcast: ' + message);
        }
        else {
            c.send(message);
        }
    }
};

module.exports = Remote;

@@ impress.remote.server.js

/**
 * impress.remote.server.js
 *
 * MIT Licensed.
 *
 * Copyright 2012 Yoshihiro Sasaki (@aloelight)
 */
var Remote = require('./impress.remote')
    , opt = require('getopt');

// set default opt
var host = '127.0.0.1', port = 3000;

try {
    opt.setopt("h:p:");
} catch (e) {
    console.dir(e);
    process.exit(1);
}
opt.getopt(function(o,p) {
    switch(o) {
        case "h":
            host = p[0];
            break;
        case "p":
            port = p[0];
            break;
    }
});

var server = new Remote({host:host, port:port});
console.log("Starting Impress.js Remote Server(%s:%s)...", host, port);

@@ impress.remote.client.js

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

@@ jquery.scrollTo-min.js

/**
 * jQuery.ScrollTo - Easy element scrolling using jQuery.
 * Copyright (c) 2007-2009 Ariel Flesler - aflesler(at)gmail(dot)com | http://flesler.blogspot.com
 * Dual licensed under MIT and GPL.
 * Date: 5/25/2009
 * @author Ariel Flesler
 * @version 1.4.2
 *
 * http://flesler.blogspot.com/2007/10/jqueryscrollto.html
 */
;(function(d){var k=d.scrollTo=function(a,i,e){d(window).scrollTo(a,i,e)};k.defaults={axis:'xy',duration:parseFloat(d.fn.jquery)>=1.3?0:1};k.window=function(a){return d(window)._scrollable()};d.fn._scrollable=function(){return this.map(function(){var a=this,i=!a.nodeName||d.inArray(a.nodeName.toLowerCase(),['iframe','#document','html','body'])!=-1;if(!i)return a;var e=(a.contentWindow||a).document||a.ownerDocument||a;return d.browser.safari||e.compatMode=='BackCompat'?e.body:e.documentElement})};d.fn.scrollTo=function(n,j,b){if(typeof j=='object'){b=j;j=0}if(typeof b=='function')b={onAfter:b};if(n=='max')n=9e9;b=d.extend({},k.defaults,b);j=j||b.speed||b.duration;b.queue=b.queue&&b.axis.length>1;if(b.queue)j/=2;b.offset=p(b.offset);b.over=p(b.over);return this._scrollable().each(function(){var q=this,r=d(q),f=n,s,g={},u=r.is('html,body');switch(typeof f){case'number':case'string':if(/^([+-]=)?\d+(\.\d+)?(px|%)?$/.test(f)){f=p(f);break}f=d(f,this);case'object':if(f.is||f.style)s=(f=d(f)).offset()}d.each(b.axis.split(''),function(a,i){var e=i=='x'?'Left':'Top',h=e.toLowerCase(),c='scroll'+e,l=q[c],m=k.max(q,i);if(s){g[c]=s[h]+(u?0:l-r.offset()[h]);if(b.margin){g[c]-=parseInt(f.css('margin'+e))||0;g[c]-=parseInt(f.css('border'+e+'Width'))||0}g[c]+=b.offset[h]||0;if(b.over[h])g[c]+=f[i=='x'?'width':'height']()*b.over[h]}else{var o=f[h];g[c]=o.slice&&o.slice(-1)=='%'?parseFloat(o)/100*m:o}if(/^\d+$/.test(g[c]))g[c]=g[c]<=0?0:Math.min(g[c],m);if(!a&&b.queue){if(l!=g[c])t(b.onAfterFirst);delete g[c]}});t(b.onAfter);function t(a){r.animate(g,j,b.easing,a&&function(){a.call(this,n,b)})}}).end()};k.max=function(a,i){var e=i=='x'?'Width':'Height',h='scroll'+e;if(!d(a).is('html,body'))return a[h]-d(a)[e.toLowerCase()]();var c='client'+e,l=a.ownerDocument.documentElement,m=a.ownerDocument.body;return Math.max(l[h],m[h])-Math.min(l[c],m[c])};function p(a){return typeof a=='object'?a:{top:a,left:a}}})(jQuery);

__END__
