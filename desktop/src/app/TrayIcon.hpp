#pragma once

#include "core/IconState.hpp"

#include <QColor>
#include <QIcon>

namespace moatbar {

/// Draws the tray icon: the OpenMoat floating croc, marked for the state the
/// same way as on macOS (red or amber tile behind it, a red dot for new blocks,
/// faded when moat is missing).
[[nodiscard]] QIcon trayIcon(IconState state);

/// A white template icon (the agent icons) recoloured for a menu.
[[nodiscard]] QIcon tintedIcon(const QString &resource, const QColor &color);

/// The croc as an application icon for About and notifications.
[[nodiscard]] QIcon appIcon();

} // namespace moatbar
