'use strict';

class IntroMovie {
	static moviePanel: MoviePanel | null = null;
	static videoPath: string = "file://{resources}/media/intro.webm"; // Put your video file name here

	static {
		$.RegisterForUnhandledEvent('ShowIntroMovie', this.showIntroMovie.bind(this));
	}

	static showIntroMovie() {
		// Get the root panel defined in your XML (<IntroMovie>)
		const rootPanel = $.GetContextPanel();
		if (!rootPanel) return;

		// Create the Movie panel dynamically inside the layout
		this.moviePanel = $.CreatePanel('Movie', rootPanel, 'IntroMoviePlayer') as MoviePanel;
		
		// Set properties and source path
		this.moviePanel.SetAttributeString('src', this.videoPath);
		this.moviePanel.SetMovieLoop(false);
		
		// Listen for the video finishing to clean up the UI
		$.RegisterEventHandler('MoviePlayerPlaybackEnded', this.moviePanel, () => {
			this.finishIntro();
		});

		// Fallback skip layout: clicking or pressing a key ends the intro
		rootPanel.RegisterEventHandler('Activated', () => {
			this.finishIntro();
		});
		
		// Start playback
		this.moviePanel.Play();
	}

	static finishIntro() {
		// Safeguard against double execution
		if (!this.moviePanel) return;

		// Destroy the video UI panel safely
		this.moviePanel.DeleteAsync(0.0);
		this.moviePanel = null;

		// Tell the engine the intro is done so it moves to the Main Menu
		$.DispatchEvent('HideIntroMovie');
	}
}
