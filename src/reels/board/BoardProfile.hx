package reels.board;

import reels.config.SpeedProfile;

/**
 * Per-cell or flat speed profile. Call with a cell to resolve a concrete
 * {@link SpeedProfile} (stagger waves use the cell argument).
 */
typedef BoardProfile = BoardCell->SpeedProfile;
