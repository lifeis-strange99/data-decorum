/**
 * @packageDocumentation
 * Captioning Interface
 */

interface Caption {
    bLowPriority: boolean;
    bSFX: boolean;
    nNoRepeat: number;
    nDelay: number;
    flLifetimeOverride: number;
    text: string;
    options: Map<string, string>;
}

interface GlobalEventNameMap {
    BadCaptionRequest: (token: string, lifetime: number) => void;
    DisplayCaptionRequest: (token: string, caption: Caption, lifetime: number, time: number) => void;
    DisplayRawCaptionRequest: (text: string, lifetime: number) => void;
    CaptionTick: (time: number) => void;
}
