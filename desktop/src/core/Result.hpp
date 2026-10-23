#pragma once

#include <QString>

#include <functional>
#include <type_traits>
#include <utility>
#include <variant>

namespace moatbar {

/// Why OpenMoat Bar could not read moat.
struct MoatError {
    enum class Kind {
        NotInstalled, ///< No moat binary was found.
        TimedOut,     ///< moat ran past the time limit.
        Failed,       ///< moat exited non-zero; `detail` is the first line it printed.
        Unreadable,   ///< moat printed something OpenMoat Bar could not decode.
    };

    Kind kind;
    QString command;
    QString detail;

    /// One line for the menu.
    [[nodiscard]] QString message() const;

    friend bool operator==(const MoatError &, const MoatError &) = default;
};

/// A value or the reason there is none. A small stand-in for C++23's
/// `std::expected`, so every call that reads moat states its failure in its type.
template <typename T>
class [[nodiscard]] Result {
public:
    // Implicit on purpose: `return value;` and `return MoatError{...};` both read naturally.
    Result(T value) : m_data(std::in_place_index<0>, std::move(value)) {} // NOLINT(google-explicit-constructor)
    Result(MoatError error) : m_data(std::in_place_index<1>, std::move(error)) {} // NOLINT(google-explicit-constructor)

    [[nodiscard]] bool ok() const noexcept { return m_data.index() == 0; }
    explicit operator bool() const noexcept { return ok(); }

    [[nodiscard]] const T &value() const & { return std::get<0>(m_data); }
    [[nodiscard]] T &&value() && { return std::get<0>(std::move(m_data)); }
    [[nodiscard]] const MoatError &error() const { return std::get<1>(m_data); }

    /// `value()` when there is one, else `fallback`.
    [[nodiscard]] T valueOr(T fallback) const & { return ok() ? value() : std::move(fallback); }

    /// Transform the value, keeping an error as it is.
    template <typename F>
    [[nodiscard]] auto map(F &&f) const & -> Result<std::invoke_result_t<F, const T &>> {
        if (ok()) {
            return std::invoke(std::forward<F>(f), value());
        }
        return error();
    }

private:
    std::variant<T, MoatError> m_data;
};

} // namespace moatbar
