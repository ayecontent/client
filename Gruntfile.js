"use strict";

module.exports = function (grunt) {
  // Show elapsed time at the end
  require("time-grunt")(grunt);
  // Load all grunt tasks
  require("load-grunt-tasks")(grunt);

  // Project configuration.
  grunt.initConfig({

    // Project settings
    yeoman: {
      // Configurable paths
      dist: "dist"
    },

    jshint: {
      options: {
        jshintrc: ".jshintrc",
        reporter: require("jshint-stylish")
      },
      all: [
        "Gruntfile.js",
        "index.js"//,
//        "lib/{,*/}*.js",
//        "config/{,*/}*.js"
      ]
    },
    watch: {
      coffee: {
        files: ["index.coffee", "lib/{,*/}*.{coffee,litcoffee,coffee.md}", "config/{,*/}*.{coffee,litcoffee,coffee.md}"],
        tasks: ["coffee:dist"]
      },
      gruntfile: {
        files: ["Gruntfile.js"]
      }
    },

    clean: {
      dist: {
        files: [
          {
            dot: true,
            src: [
              "<%= yeoman.dist %>/*",
              "!<%= yeoman.dist %>/.git*"
            ]
          }
        ]
      }
    },
    // Compiles CoffeeScript to JavaScript
    coffee: {
      dist: {
        files: [
          {
            expand: true,
            src: ["index.{coffee,litcoffee,coffee.md}", "lib/{,*/}*.{coffee,litcoffee,coffee.md}", "config/{,*/}*.{coffee,litcoffee,coffee.md}"],
            dest: "<%= yeoman.dist %>",
            ext: ".js"
          }
        ]
      }
    },

    // Copies remaining files to places other tasks can use
    copy: {
      dist: {
        files: [
          {
            expand: true,
            dot: true,
            dest: "<%= yeoman.dist %>",
            src: [
              "**/*.json",
              "!package.json",
              "node_modules/**/*.js"
            ]
          }
        ]
      }
    },

    // Run some tasks in parallel to speed up build process
    concurrent: {
      dist: [
        "coffee"
      ]
    }
  });


  grunt.registerTask("serve", function (target) {
    if (target === "dist") {
      return grunt.task.run(["build"]);
    }

    grunt.task.run([
      "clean:dist",
      "copy:dist",
      "coffee:dist",
      "watch"
    ]);
  });


  grunt.registerTask("build", [
    "clean:dist",
    "concurrent:dist",
    "copy:dist"
  ]);

  grunt.registerTask("default", [
//    "newer:jshint",
    "build"
  ]);
};
